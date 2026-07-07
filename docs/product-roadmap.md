# Open Finance — v1 Product Roadmap

**Project**: Personal Finance Workspace for macOS
**Scope**: v1 as defined in `docs/product-requirements.md` and `docs/technical-design.md`
**Architecture reference**: File layer → Parsing layer → Domain layer → Projection layer → Presentation layer
**Last updated**: 2026-07-06 (Phases 1–6 complete and merged to `main`, PRs #15–#21; Phase 6 write flows landed via PR #21. Phase 7 is the active phase; Phase 8 added for out-of-scope follow-ups — see status banners & changelog)

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
| Live price ingestion strategy (endpoint choice, polling interval, error handling) | V2 |
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
    ↓ (v1 hardened; deferred residue picked up)
Phase 8: Out-of-Scope Follow-ups (post-v1 backlog)
```

> **Build status (2026-07-06):** **Phases 1–6 are complete and merged to `main`** (PRs #15–#21).
> The app is a Swift Package with a generated XcodeGen app target (`App/project.yml`, CI-built
> unsigned). **Phase 7 (Polish & Launch Readiness) is the active phase.** Phase 8 gathers the
> follow-ups deliberately deferred during Phases 1–6 (canonical list:
> `docs/out-of-scope-followups.md`).

---

## Phase 1: Foundation & Architecture

**Goal**: Establish the Xcode project, iCloud workspace management, file indexing infrastructure,
and core internal data models. Nothing is visible to users yet — this phase builds the floor that
every subsequent layer stands on.

**⚠️ Critical dependency**: All later phases depend on `WorkspaceManager` and `FileIndexService`
being stable. Do not advance to Phase 2 until the workspace URL resolves reliably in both iCloud
and local-fallback modes.

> **✅ Status (2026-06-28): COMPLETE — merged to `main` via PR #15.** Delivered as spec
> `specs/002-foundation-architecture` (49 of 50 tasks done). All four user stories shipped:
> US1 provisioning, US2 file index, US3 sync-state/conflict handling, US4 dev-env + CI. The
> Development tasks below are all implemented; the unchecked `[ ]` boxes are retained for
> historical task detail.
>
> **Packaging reality:** the foundation was built as a **Swift Package** (`Package.swift`) — a
> `FinanceWorkspaceKit` library target plus `FinanceWorkspaceApp` and the `bootstrap-workspace` /
> `fixture-generate` / `index-check` executables — *not* a hand-authored `.xcodeproj`. The
> CLT-only build environment (no Xcode GUI / `xcodegen`) made SwiftPM the buildable, CI-friendly
> choice. Architecture module folders map to `Sources/FinanceWorkspaceKit/{Platform,Domain,Validation,Persistence,Parsing}/`.
> The "Xcode Project Setup" sub-section below was realized through SwiftPM equivalents.
>
> **Deferred:** the iCloud ubiquity-container **entitlement** (and developer-machine code
> signing) is the one outstanding Phase 1 item — it needs the Xcode app target, added when
> UI/packaging/signing is required (later phase). The `ICloudContainerService` code path itself
> is implemented.
>
> **CI note:** macOS build/test CI (`.github/workflows/ci-macos.yml`) landed in Phase 1
> alongside the Linux SwiftLint runner — the "full Mac build CI deferred to Phase 5" intent below
> is superseded.

### Product Tasks

- [x] Lock the Phase 1 architectural decisions documented in `docs/technical-design.md §21` ✓ 2026-06-10
  - Unified `Accounts/accounts.csv` — no separate `Investments/accounts.csv`
  - Savings/ and Investments/ stay as separate folders at the file level
  - One `Taxes/tax-adjustments.csv` with an `adjustment_type` column (Round 6 rename of `deductions.csv` / `deduction_type`)
  - Tax year-close is an explicit in-app action only
  - Right detail pane is closed by default globally, no per-section exceptions
  - iCloud container identifier: `iCloud.com.<org>.OpenFinance` (R8 — corrected from bare `OpenFinance`)
  - Bootstrap seeds: personal bank, personal credit card, business bank, business credit card, savings, investment
- [x] Finalize iCloud entitlement strategy ✓ R8 — single `iCloud.<bundle-id>` container across
  dev and distribution (corrected from the bare `OpenFinance` value); dev-data isolated via the
  DEBUG local-folder provider, not a separate container
- [x] Document the 7 required iCloud sync states and how each surfaces ✓ R8 — UI-treatment table in
  `docs/technical-design.md §5`; state sourced from `NSMetadataQuery`; conflicts resolved manually
  via `NSFileVersion`
- [ ] Define the complete workspace folder structure and file naming conventions (confirm against
  `docs/technical-design.md §6`)
- [ ] Document workspace bootstrap behavior: full sequence — folders created, seed files written,
  six starter accounts written to `Accounts/accounts.csv`, manifest created
- [x] Define the manifest shape and update contract ✓ R8 — device-local cache in Application Support;
  field set in `docs/technical-design.md §9`

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

#### Phase 0 — Project & Environment Bootstrap (do first)
> A lightweight pre-platform checklist (R8). The Phase 1 advancement gate — "workspace
> URL resolves reliably in both iCloud and local-fallback modes" — is verified here.
- [ ] Configure the ubiquity-container entitlement with the `iCloud.<bundle-id>` identifier; set up
  local-dev code signing
- [ ] Implement the DEBUG local-folder `CloudStorageProvider` rooted at `~/Finance-Dev/`
- [ ] `fixture-generate` script — realistic 12-month dataset written to `~/Finance-Dev/`
- [ ] Wire SwiftLint + GitHub Actions (Linux runner) and confirm green
- [ ] Smoke test: workspace URL resolves in **both** iCloud and local-folder modes
- [ ] Author the file schemas (one JSON schema per managed file type) in `.finance-meta/schemas/` (source of truth for registry,
  validation, bootstrap, migration)

#### Xcode Project Setup
- [ ] Create `FinanceWorkspaceApp` Xcode project targeting macOS with SwiftUI lifecycle
- [ ] Configure iCloud entitlement (`com.apple.developer.ubiquity-container-identifiers`) and
  capabilities
- [ ] Establish module folder structure: `App/`, `Platform/`, `Parsing/`, `Domain/`, `Validation/`,
  `Persistence/`, `UI/Shared/`, `Scripts/`
- [ ] Set up `SwiftLint` and code style configuration. **CI/CD:** GitHub Actions runs SwiftLint on a standard Linux runner in Phase 1 (no Mac build runner required). Full Mac build CI is deferred to Phase 5. Code signing and entitlements are developer-machine only until Phase 5.
- [ ] Configure unit test target and basic test infrastructure

#### Platform Layer
- [ ] `CloudStorageProvider` protocol — define minimum interface: `resolveWorkspaceURL() async throws -> URL`, observable `syncState`, `isAvailable: Bool`; all storage backends conform to this protocol; `ICloudContainerService` is the v1 implementation
- [ ] `ICloudContainerService` — conforms to `CloudStorageProvider`; resolve ubiquity container URL
  (identifier `iCloud.<bundle-id>`), expose availability state enum, source per-file sync state from
  `NSMetadataQuery`, resolve conflicts manually via `NSFileVersion` (no auto-merge),
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
- [ ] `FileWatcherService` — `NSMetadataQuery` (iCloud provider; also yields per-file sync
  state) + FSEvents (local-folder provider) to observe the workspace for file system events,
  debounce rapid changes, trigger incremental re-index. (`DispatchSource` / `NSFilePresenter`-as-watcher rejected — R8.)
- [ ] `ManifestStore` — read/write the **device-local** manifest at
  `~/Library/Application Support/OpenFinance/<workspace_id>/manifest.json` (out of the synced
  container), maintain last-indexed snapshot, cache classification results and validation status
  per file, rebuild from scan if missing/corrupt

#### Core Data Models
- [ ] Define `Workspace`, `FileRecord`, `SyncStatus` models in `Platform/`
- [ ] Define `ValidationIssue`, `RepairAction` models in `Validation/`
- [ ] Define canonical entity models for all domains in `Domain/`:
  `Account`, `AccountGroup`, `Liability`, `AccountRule`, `AccountEstimate`, `UnifiedTransaction`, `Category`,
  `Budget`, `BudgetAllocation`, `SavingsGoal`, `SavingsProgress`, `Asset`, `Trade`,
  `PricePoint`, `BenchmarkPeriod`, `Portfolio`, `PortfolioSleeve`, `SleeveTarget`,
  `EstimatedPayment`, `TaxAdjustment`, `TaxEstimate`, `TaxDocument`, `TaxArchiveYear`, `NoteDocument`
  (`OwnerDistribution` removed in R8 — out of v1 scope). `Account` is a single struct with optional
  nested `InvestmentMetadata?`.
  (Round 6: `UnifiedTransaction` carries multi-entry `group_id`/`group_role`, `sending_asset_id`/`receiving_asset_id`/`liability_id`, and `type = trade` rows that absorb the former investment ledger)
- [ ] Define cross-domain projection models:
  `AccountSummaryCard`, `OverviewSummaryCard`, `MonthlySnapshot`, `GoalFundingLink`,
  `SleeveFundingLink`, `TaxPrepSummary`, `TaxDeductionSummary`, `BusinessMonthlySummary`

#### Developer Script
- [ ] `bootstrap-workspace.swift` — create standard folder tree (including `Accounts/account-groups.csv`,
  `Accounts/liabilities.csv`, `Investments/assets.csv`, `Investments/portfolios.csv`,
  `Taxes/tax-adjustments.csv`, `Taxes/estimates.csv`, `Taxes/documents.csv`), write seed CSV/Markdown
  templates with correct headers and `schema_version: 1`, seed the standard tax-adjustment row in
  `Taxes/tax-adjustments.csv` from filing status, create manifest, write default categories in
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

> **✅ Status (2026-06-30): COMPLETE — merged to `main` via PR #16.** Delivered as spec
> `specs/003-parsing-validation` (all 43 tasks done; **Milestone 2** gate confirmed at T043). The
> Parsing layer (`CSVParserService` / `CSVSchemaRegistry` / `CSVNormalizer` / `FrontMatterParser` /
> `MarkdownParserService` / `WorkspaceParser`), the `ValidationEngine` + `RuleCatalog` (full
> catalog: 15 file + 11 cross-file + 8 domain rules in the `VAL-<TIER>-<NNN>` shape),
> `RepairService`, `SettingsStore`, and `MigrationService` all shipped, plus the
> `validate-workspace` / `repair-workspace` / `migrate-r6` CLIs. Canonical JSON schemas for all 23
> managed file types are **bundled** with the library (`Sources/FinanceWorkspaceKit/Resources/Schemas/`,
> via `Bundle.module`) and mirrored into the workspace `.finance-meta/schemas/` at bootstrap. As
> with Phase 1, the unchecked `[ ]` boxes below are retained for historical task detail — the
> **Development** tasks and the dev-facing **Product** tasks are implemented.
>
> **Not in this phase:** the **Design Tasks** below (validation issue card, repair preview panel,
> indexing progress state) are UI design that lands with the Presentation layer (Phase 5); spec
> `003` was the engine/infrastructure layer only. The intended treatments are explored in the
> static `prototype/` but are not yet committed design specs.

### Product Tasks

- [ ] Finalize and document all CSV file specifications — one per managed file type (schemas, required vs optional columns,
  enum value sets) — authored as JSON in `.finance-meta/schemas/` (R8 source of truth); each managed
  CSV carries a leading `# schema_version: N` comment row. *(R8 locked the format/approach; the full
  per-file enum enumeration remains the open work here.)*
- [ ] Define the complete validation rule catalog across three tiers, using the R8 rule shape
  (`VAL-<TIER>-<NNN>`, tier, severity, repair_class, predicate — see
  `docs/architecture/rulesets-and-taxes.md`):
  - File-level: missing required file, invalid CSV header, bad date, bad decimal, invalid enum
  - Cross-file: unknown account/category/entity/sleeve/goal reference, duplicate transaction ID
  - Domain: budget period without rows, holding without account, trade without valid ticker
- [ ] For each validation issue, classify: error vs warning vs info, and repairable vs manual-only.
  *(R8 set the classification defaults; enumerate the rest.)*
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
  amounts, `Bool`, enum cases; produce typed `NormalizationError` for invalid values. Sign-convention
  detection = explicit per-import declaration in the column-mapping step + heuristic pre-fill the user
  confirms (never silently flip — R8)

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

#### Round 6 — schema migration & multi-entry validation
- [ ] `SchemaRegistry` + JSON schemas updated for the renamed files (`account-groups.csv`, `assets.csv`, `tax-adjustments.csv`) and the new files (`liabilities.csv`, `portfolios.csv`, `budget-allocations.csv`, `Taxes/estimates.csv`, `Taxes/documents.csv`); the `UnifiedTransaction` schema gains the multi-entry and trade columns
- [ ] `migrate-r6.swift` — one-time, deterministic, preview-able migration: rename the three files/columns atomically, move `Investments/transactions.csv` rows into the unified ledger as `type = trade` rows, seed the new files, bump `schema_version`, update `manifest.json`
- [ ] ValidationEngine: multi-entry group rules — balanced groups net to zero; gross/net groups reconcile `net = gross − Σ(withholding)`; `group_id` is a shared non-unique connector

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
All transaction, asset, liability, and tax files reference `account_id` from the master
registry `Accounts/accounts.csv` (and `account_group_id` from `Accounts/account-groups.csv`) —
downstream engines validate these references.

> **✅ Status (2026-07-06): COMPLETE — merged to `main` via PR #18.** Delivered as spec
> `specs/004-domain-accounts-budget-overview` (39/39 tasks;
> **Milestone 3** reached). Shipped: the `ParsedRecord`→typed-entity record-mapping seam,
> `AccountEngine` (aggregate / per-account / per-group projections, ledger-derived balances +
> `Liability.principal_balance`, tax-year YTD net income with transfers excluded and `taxes_paid` from
> withholding legs, the personal-inflow vs **retained-equity** split, multi-entry resolution,
> multi-employment aggregation, account-rule cash-flow projection), `BudgetEngine` (plan-vs-actual
> variance over a budget's scope, partial-aware 3-month trailing average, spend-mix, goal
> contributions), `LinkingEngine` + `OverviewEngine` (five KPI cards — Budget/Savings/Business live,
> Investments/Taxes the typed "data not available" state; trailing-6-month gap-skipping MoM panel;
> aggregated validation issues), the expanded default seed (16 categories across six groups + a
> default Household budget + canonical `account_type` values), and the `accounts-overview` /
> `budget-overview` / `overview-dashboard` CLIs. `swift build` is green and the engines are verified
> end-to-end via the CLIs; `swift test` + `swiftlint --strict` run in macOS CI (the CLT-only dev box
> can't run them). The Phase-3 **Design** `[DECIDE]`s (Accounts/Budget/Overview UI) remain Phase-5
> work — this spec was the engine/model/seed layer only.
>
> **Resolved Phase-3 decisions** (baked into the spec): account-type taxonomy, default category set,
> multiple employment account-groups, 3-month trailing-average sparse handling, YTD net income
> (tax-year anchored, transfers excluded, `taxes_paid` = withholding legs), Overview card sourcing
> (Investments/Taxes stubbed), 6-month gap-skipping MoM, and the personal-inflow vs retained-equity
> split. `[FIX-C2]` closed. As with Phases 1–2, the unchecked `[ ]` boxes below are kept for
> historical task detail — the Development tasks and the dev-facing Product tasks are implemented.

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

#### Round 6 — Accounts & Budget
- [ ] `AccountEngine` derives `Liability.principal_balance` from the ledger; account screens resolve assets and liabilities per account
- [ ] `BudgetEngine` resolves each Budget's scope (account-groups/accounts) over its `budget-allocations.csv` lines

### Milestone 3 — ✅ reached (merged, PR #18)
> **Core domain engines functional.** Accounts module projects aggregate and per-account views
> from real files. Budget module produces plan-vs-actual with 3-month trailing averages from
> transaction files. Overview engine composes cross-domain KPI cards (with stubs for engines
> not yet built). Cross-domain links between budget contributions and goals are established.

---

## Phase 4: Domain Layer II — Savings, Investments & Tax

> **✅ Status (2026-07-06): COMPLETE — merged to `main` via PR #19.** Delivered as spec
> `specs/005-savings-investments-tax` (52 tasks; **Milestone 4** reached).
> Shipped: `SavingsGoalEngine`, `PortfolioEngine` (FIFO lots, valuation, sleeve drift, dividends),
> `BenchmarkEngine` (8-window heat map, simple/CAGR, sector weights), `TaxEngine` (per-account taxable
> income / taxes paid / effective rate, ST/LT realized gains), `TaxAdjustmentEngine` (std-vs-itemized,
> simplified ~20% QBI, business x-ref, computed estimate + the standard-adjustment safe write),
> `TaxPrepEngine` (fixed prep checklist + the year-close archive safe write), and the
> `LinkingEngine`/`OverviewEngine` completion (portfolio→tax + Schedule C links; all five KPI cards
> live). Four CLIs (`savings-`/`portfolio-`/`benchmark-`/`tax-overview`) + `overview-dashboard` now
> render live data; `fixture-generate` emits the new file types. `swift build` is green and every
> engine is verified end-to-end via the CLIs; `swift test` + `swiftlint --strict` run in macOS CI.
>
> **Shipped-schema reconciliations (additive, non-breaking):** the unified ledger gained optional
> `trade_type`/`quantity`/`price` (ledger-FIFO realized gains); `assets` gained `sleeve_id`;
> `portfolios` gained `expected_return_rate`; `accounts` gained `apy`. `TaxAdjustmentType` was aligned
> to the shipped enum (`schedule_a`/`schedule_c`). `Taxes/archive/` is excluded from parsing (read-only
> snapshots). See `docs/out-of-scope-followups.md` for the deferred items surfaced during the build.

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
- [ ] `PortfolioEngine` — compute position values from `Asset` × `PricePoint` (latest
  available price); compute cost basis, unrealized gain/loss, allocation per sleeve; build
  aggregate and account-level holdings views; resolve tax lots from `Trade` history; compute
  dividend income totals from `Dividend` records; compare actual sleeve weights to `SleeveTarget`
  and compute drift
- [ ] `BenchmarkEngine` — load S&P 500 price series from `benchmarks/sp500.csv`; compute %
  growth for each `BenchmarkPeriod` (D, W, M, 3M, 6M, 1Y, 3Y, 5Y) using calendar-anchored date
  lookups; compute the same periods for each portfolio account; produce heat map data model
  (`BenchmarkPeriod` × account); compute sector performance weights from holdings and compare to
  benchmark sector weights

#### TaxEngine + TaxPrepEngine + TaxAdjustmentEngine
- [ ] `TaxEngine` — compute YTD taxable income per account from income transaction records;
  compute taxes paid from `EstimatedPayment` records; derive effective tax rate per account
  (taxes paid / gross income); compute realized gain/loss from `Trade` + lot records; aggregate
  dividend and interest income from `Dividend` and transaction records
- [ ] `TaxAdjustmentEngine` (was `DeductionEngine`) — manage `TaxAdjustment` CRUD (`tax-adjustments.csv`) plus `TaxEstimate` and `TaxDocument`; seed the standard adjustment row on first
  access using `WorkspaceSettings.filingStatus` and `taxYear`; compute taxable income minus
  adjustments; cross-reference business-expense adjustments with `AccountEngine` for account-group-level
  expense totals; produce `TaxDeductionSummary` with all deduction categories
- [ ] `TaxPrepEngine` — evaluate tax prep checklist items against available data; classify each
  item as complete, incomplete, or missing; detect unresolved issues from `ValidationIssue` records
  tagged as tax-relevant; manage `TaxArchiveYear` read/write (write on year-close action, enforce
  read-only thereafter)

#### CrossDomain Completion
- [ ] Complete `LinkingEngine` — add portfolio-to-tax links (realized gains → tax engine),
  business entity tax links (Schedule C categories → deduction engine); update `OverviewEngine`
  to consume real projections from all engines (remove stubs from Phase 3)

#### Round 6 — Savings, Investments & Tax
- [ ] `PortfolioEngine` gains the Portfolio container above sleeves; reads investment trades as `type = trade` rows from the unified ledger (former `Investments/transactions.csv` deprecated) — larger refactor of the investment ingestion path
- [ ] `TaxAdjustmentEngine` (was `DeductionEngine`) manages tax-adjustments, tax-estimates, and the tax-document registry

### Milestone 4 — ✅ reached (merged, PR #19)
> **All domain engines functional.** Every module can produce complete projections from fixture
> data. Cross-domain links are live: budget contributions feed goals, portfolio gains feed tax
> summaries, business entity expenses feed Schedule C deductions. Overview engine composites all five
> KPI cards from real data.

---

## Phase 5: Presentation Layer — App Shell & All Module Views

> **✅ Status (2026-07-06): COMPLETE — merged to `main` via PR #20.** Delivered as spec
> `specs/006-presentation-layer` (**Milestone 5** reached). Shipped the full SwiftUI presentation
> layer against live engine projections: `FinanceWorkspaceApp`/`AppState`/`AppRouter`, the
> `NavigationSplitView` shell (248px sidebar, global issues+sync chips, per-view local actions),
> the collapsible right inspector (⌥⌘I, six surfaces), the shared component library (KPI card,
> data table, pie/sparkline/bar/heat-map on Swift Charts, period selector, empty state, loading
> skeleton), and all five module view groups (Overview, Accounts, Budget, Savings & Investments,
> Taxes) with full KPI → detail → source-file traceability. **The generated XcodeGen app target
> landed here** (`App/project.yml`, T060/T061 — CI-built unsigned; signing/notarization deferred
> to Phase 7). Phase 5 shipped **strictly read-only** — every write affordance rendered
> visible-but-disabled and repair was preview-only until Phase 6. Verified automatically: boots
> against fixture + empty workspaces, SC-005 read-only tar-compare proof, engine⇄view parity
> tests. `swift test` + SwiftLint + unsigned app-target build gate in CI.

**Goal**: Build the complete SwiftUI presentation layer. The app shell ships first; module
views can be developed in parallel once the shell and navigation state are stable.

**⚠️ Critical dependency**: `AppState` and `AppRouter` must be stable before any module view
is connected. Module views are blocked on their respective domain engines from Phase 3/4.

### Product Tasks

- [x] Write acceptance criteria for each module view against PRD functional requirements
- [x] Define filter states: which filters appear per section, default state, persistence scope
  (session-only vs persisted), and interaction with the detail pane
- [x] Define the traceability interaction: what tapping a KPI does, what tapping a detail row
  does, how the source file inspector appears and what it shows
- [x] Define the collapsible right pane interaction spec: trigger (click, keyboard shortcut,
  selection-driven auto-open), animation, width, and content rules per context
- [x] Document all macOS menu bar commands and their keyboard shortcuts
  (reference `docs/technical-design.md §17`)

### Design Tasks

#### App Shell
- [x] Finalize `NavigationSplitView` three-column layout spec: sidebar width, column collapse
  behavior, minimum window size
- [x] Design left sidebar: section headers, expandable/collapsible groups, nested entity links,
  active/selected state, empty group state
- [x] Design the context header: title, breadcrumb, quick actions (Import, Add, Export),
  sync status badge, issue count badge
- [x] Design the right detail pane: slide-over width, close button, all supported surfaces
  (inspector, source file preview, source row detail, validation issue detail, repair preview,
  edit form)
- [x] Design shared component library: data table (sortable, filterable), KPI card, chart
  components (pie chart, sparkline, bar chart, heat map table), period selector, filter bar,
  empty state template, loading skeleton

#### Module Views
- [x] Finalize Overview dashboard wireframe (updated post Round 1 — see `docs/_refinement/`)
- [x] Finalize app-shell wireframe (Round 5: Overview is the default landing via the sidebar
  header; issues chip in the global header; local-actions on the page-title line; no filter bar)
- [x] Finalize Accounts views wireframe (new — account-group screen with individual-account
  cards + inline ledger, no sub-tabs; dedicated per-account screen with transactions table)
- [x] Finalize Budget updated wireframe (pie chart + trailing averages + 50/50 Spend Mix /
  Spending Variance panels)
- [x] All chart visuals designed for a real charting implementation (Swift Charts), not
  placeholder SVGs
- [x] Finalize Savings & Investments unified wireframe
- [x] Finalize Taxes updated wireframe (deductions view, per-account rates)

### Development Tasks

#### App Shell
- [x] `FinanceWorkspaceApp` — define `WindowGroup` scene, main menu commands (`NSApplication`
  delegate or `.commands` modifier), app-level keyboard shortcuts
- [x] `AppState` — `@Observable` root state object holding workspace state, indexing state,
  active module selection, navigation path, detail pane open/closed state; **Overview is the
  default selection on launch**
- [x] `AppRouter` — manage navigation selection for `NavigationSplitView`, encode/decode deep
  link state (domain + group/account selection), handle programmatic navigation from KPI links;
  the sidebar header ("Finance Dashboard") navigates to the Overview dashboard
- [x] `NavigationSidebarView` — left sidebar with expandable section groups, nested account-
  group/account/goal/sleeve links, active selection highlight, keyboard navigation; **no
  Overview nav row** (Overview is reached via the header); Accounts nested group is labelled
  "Account groups" with a "New group" action
- [x] Global top header — issues-count chip immediately left of the sync-status chip; per-view
  local-actions row rendered on the page-title line (right-aligned)
- [x] `DetailPaneView` — collapsible slide-over container with all supported surface types,
  open/close animation, closed by default; edit and delete actions at the bottom for
  right-panel objects

#### Shared UI Components (`UI/Shared/`)
- [x] `KPICardView` — reusable card with title, primary value, secondary value, trend indicator,
  tap target → navigation action
- [x] `DataTableView` — sortable/filterable table with column definitions, row selection,
  traceability tap target per row
- [x] `PieChartView` — configurable donut/pie with legend, labels, percentage display (Swift Charts)
- [x] `SparklineView` — small in-line trend line for month-over-month panels (Swift Charts)
- [x] `HeatMapTableView` — benchmark comparison table with period columns, color-scaled cells,
  benchmark comparison row (Swift Charts)
- [x] `PeriodSelectorView` — month/quarter/year selector with previous/next navigation
- [x] ~~`FilterBarView` — composable filter chips~~ **(deferred to V2 — filter bar removed from v1)**
- [x] `EmptyStateView` — configurable empty state with icon, title, message, and optional CTA
- [x] `SourceInspectorView` — shows file path, row number, last modified date, raw field values
  for a selected record; "Open in Finder" and "Open in Editor" actions
- [x] `ValueProvenanceLabel` — inline label distinguishing imported / derived / repaired /
  user-edited values

#### Overview Module (`UI/Overview/`)
- [x] `OverviewView` — 5 KPI card grid (no filters), month-over-month panel, inline issues table;
  each KPI card navigates to its module on tap
- [x] `OverviewIssuesTableView` — validation issues grouped by severity, repairable badge,
  "Preview Repair" action per repairable issue

#### Accounts Module (`UI/Accounts/`)
- [x] `AccountsView` — card grid of all accounts with aggregate header; grouped by account
  group; account cards tap → per-account screen
- [x] `AccountGroupDetailView` — account-group screen with an individual-account card section
  above the transaction ledger (no sub-tabs); for business groups, P&L summary + monthly
  net-income chart with the ledger inline below it, category budgets, linked notes
- [x] `AccountDetailView` — per-account screen: transactions table, monthly gross vs expenses/tax
  chart, YTD net income; Import, Add, Edit, Delete actions; account rules and estimates panel;
  edit in local actions, delete inside the edit flow

#### Budget Module (`UI/Budget/`)
- [x] `BudgetOverviewView` — pie chart, Spend Mix / Spending Variance panels at 50/50, category
  table with plan/actual/variance/trailing-average, period selector; tap category → filtered
  transaction view
- [x] `BudgetHistoryView` — month-over-month variance view, period range selector
- [x] `BudgetCategoriesView` — category and subcategory management, manual create/edit forms

#### Savings & Investments Module (`UI/SavingsInvestments/`)
- [x] `SavingsInvestmentsView` — top-level view with Overview, Goals, and Portfolio sub-navigation
- [x] `GoalsListView` — flat list of goal cards with progress bar (no active/archived grouping),
  tap → goal detail
- [x] `GoalDetailView` — progress history chart, funding source links, monthly contribution
  tracker, source traceability
- [x] `PortfolioView` — holdings table as the primary surface with a standard ⇄ heat-map view
  toggle (heat map: 8 periods × accounts, S&P 500 comparison row, sector performance section);
  allocation donut and account selector as supporting elements; sleeve table at the bottom
  (target vs actual weights, contribution target, drift indicator)
- [x] `HoldingDetailView` — security detail, tax lot drill-down, trade history, dividend summary

#### Taxes Module (`UI/Taxes/`)
- [x] `CurrentTaxYearView` — YTD taxable income, taxes paid vs owed, effective rate per account
  table; estimated payments section (quarterly schedule, paid/due status); gains & income section
  (realized gain/loss, dividends, interest); deductions section (standard vs itemized,
  above-the-line, Schedule A, Schedule C linked to business themes/entities, taxable income
  projection); no prep checklist
- [x] `TaxPrepChecklistView` — full-width checklist with complete/incomplete/missing item states,
  source links, and educational content per step
- [x] `TaxArchiveView` — prior-year read-only archive selector, archived deductions and payments

#### Round 6 — module surfaces
- [x] Account-group and per-account screens surface both assets and liabilities (net-worth view)
- [x] Savings & Investments organized by Portfolio; add Portfolio views above the sleeve table
- [x] Multi-entry transaction editor: a paycheck (gross → withholdings → net) or split mortgage payment (principal/interest) is entered as one grouped unit, not flat rows

### Milestone 5 — ✅ reached (merged, PR #20)
> **Fully navigable app.** All v1 module views are built and connected to real domain engine
> projections. The right detail pane works across all contexts. Traceability links are live
> (KPI → detail → source inspector). The app is demoed end-to-end against a fixture workspace.
>
> **Status (2026-07-04, `006-presentation-layer`)**: build complete — automated gate evidence
> passed (boot against fixture + empty workspaces, SC-005 read-only proof, engine⇄view parity
> tests); the interactive demo script is `docs/test-plans.md` Flow 9 (manual pass pending);
> CI (`swift test` + SwiftLint + unsigned app-target build) validates on push.

---

## Phase 6: Write Flows, Repair & Export

> **✅ Status (2026-07-06): BUILD COMPLETE — merged to `main` via PR #21.** Delivered as spec
> `specs/007-write-flows-repair-export` (**Milestone 6** reached for its shipped scope). The
> read-only Phase-5 app is now **writable** through one Kit-level write engine
> (`Sources/FinanceWorkspaceKit/Persistence/Write/`: `WritePlan`, `WriteService`,
> `CSVRowSerializer`, `ReferenceScanner`, `ImportMapper`, `ExportService`, `MultiEntry`) that
> composes the Phase-1 safe-write primitives (`BackupService`/`FileCoordinatorService`/`WriteGate`/
> `ManifestStore`) — never reimplementing them. Shipped end-to-end and CI-tested (six
> `WriteEngineTests` suites): **US1** add/edit/delete of all 12 row entities via preview → backup →
> atomic apply → re-index (⌘N add, panel-bottom Edit/Delete, in-app Close-Tax-Year); **US2** CSV
> import (⇧⌘I — column map + single target account + sign + month-split + duplicate flag); **US4**
> delete-with-reference reassignment (never orphans — atomic delete + reassignment plan); **US5**
> guided repair apply (⇧⌘R, issues table + detail pane → re-validate); **US6** Export Current View
> (⌘E — CSV with provenance). The **US3 multi-entry write/reconciliation engine** shipped and is
> unit-tested. `swift build` green; `swift test` + `swiftlint --strict` + unsigned app-target build
> gate in CI.
>
> **UI residue deferred (tracked in `docs/out-of-scope-followups.md`):** the multi-entry
> `TransactionGroupEditor` + ledger group edit/delete (OOS-16, engine done); the interactive
> per-collection `ReassignmentPickerView` (OOS-17, delete defaults to first target today); the
> Budget Markdown-summary export button (OOS-18, `budgetSummaryMarkdown` exists + tested). Plus
> the D10 per-entity typed forms (OOS-13), dedicated-screen account edit placement (OOS-14), and an
> optional `description` column on `transactions` (OOS-15). A handful of App-target view-model /
> integration tests (T010/T021/T032/T036) are also deferred. **All are folded into Phase 7** under
> *Complete Phase 6 write flows*.

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
- [x] **Prototype update** — `prototype/app.js` demonstrates write/edit/delete flows: add transaction
  modal + manual single-entry, edit side panels (account/transaction/goal/category/group), delete with
  reference-check reassignment preview (per-collection picker, atomic delete + reassign), and a two-step
  import CSV column-mapping flow (file picker → auto-detected mapping table → import). Resolved Round 7
  (`[FIX – R7-P1]` in `docs/project-management.md`)

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
- [ ] Add/edit/delete `Account` and `AccountGroup` → writes to `Accounts/accounts.csv` / `Accounts/account-groups.csv`
- [ ] Import CSV transactions → column mapper → appends to `Accounts/transactions/YYYY-MM.csv`
- [ ] Add/edit/delete `Transaction` inline → writes to correct monthly file (multi-entry groups written atomically)
- [ ] Add/edit/delete `Category` / `Budget` / `BudgetAllocation` rows
- [ ] Add/edit/delete `SavingsGoal`
- [ ] Add/edit/delete `Asset` / `Liability` → writes to `Investments/assets.csv` / `Accounts/liabilities.csv`
- [ ] Add/edit/delete `TaxAdjustment` → writes to `Taxes/tax-adjustments.csv`
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

#### Round 6 — multi-entry writes
- [ ] Multi-entry transaction groups are written/edited/deleted atomically (all rows sharing a `group_id` move together; the group must pass its balance/reconciliation check before write)

### Milestone 6 — ✅ reached (2026-07-06, PR #21)
> **App is writable.** Users can add/edit/delete the 12 row entities, import transactions, manage
> goals and tax-adjustments, delete-with-reassignment, and trigger guided repairs — all writes
> atomic, backed up, sync-gated, and confirmed by preview. Export works for CSV tables (Markdown
> summary engine shipped; its in-view button is deferred). Import CSV handles real bank/brokerage
> formats with month-split + dedup.
>
> **Folded into Phase 7** (unfinished write-flow work — `docs/out-of-scope-followups.md`):
> in-app multi-entry paycheck/transfer authoring (OOS-16), the interactive reassignment picker
> (OOS-17), the Budget Markdown export button (OOS-18), D10 per-entity typed forms (OOS-13),
> dedicated-screen account-edit placement (OOS-14), and the optional `transactions.description`
> column (OOS-15).

---

## Phase 7: Polish & Launch Readiness

> **🔵 Status (2026-07-06): ACTIVE — branch `008-polish-launch`.** Not yet specced; the task list
> below is the pre-spec backlog. Some hardening groundwork already exists from Phases 1–6 and is
> annotated inline (✅ done / 🟡 partial) so this phase can focus on the true gaps. The two biggest
> net-new items are **code signing + notarization of the app target** (the entitled XcodeGen target
> exists and builds unsigned in CI — `docs/out-of-scope-followups.md` OOS-1) and **real iCloud sync
> testing on a signed build**. This phase adds **no new features** — it hardens what phases 1–6
> shipped **plus** the unfinished Phase-6 write-flow work (OOS-13…OOS-18 + deferred write tests),
> folded in here under *Complete Phase 6 write flows* so the writable app is feature-complete before
> launch. Phase 8 now holds only the engine/read-model + repair-infra residue and pure-V2 items.
>
> **⚠️ Known gap to close first (Phase-6 completion):** the **top-level Import / Add / Edit buttons
> are still disabled in the running app.** Phase 6 shipped the write engine, the ⌘N add command, the
> detail-pane Edit/Delete, and the preview/import/edit-form views — but the module page-title actions
> were never switched from their Phase-5 `LocalAction.writeStub(...)` placeholders (hardcoded
> `isEnabled: false`) to live handlers, so writes are only reachable by keyboard/inspector. See the
> **Write-affordance enablement** task group below — this is the first thing Phase 7 must fix.

**Goal**: Production-quality reliability, performance, accessibility, and macOS native behavior.
No new features — this phase hardens everything built in phases 1–6.

### Product Tasks

- [ ] Write the complete validation fixture suite: one valid and one invalid file per file type,
  covering all repairable and manual-only issue types
  - 🟡 Partial — per-engine unit fixtures exist (`Tests/FinanceWorkspaceKitTests/`); the systematic
    one-valid/one-invalid-per-file-type matrix is the remaining work
- [ ] Define performance acceptance criteria: initial indexing time for a realistic dataset
  (12 months × unified transactions × 3 entities), UI frame rate during re-index,
  time-to-first-projection on cold launch (SC-002 hard thresholds + Apple-Silicon baseline)
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

#### Write-affordance enablement (completes Phase 6 — do first)
> Phase 6 built the write flows but left the primary buttons wired to Phase-5 disabled
> placeholders. Until this lands, users cannot Import/Add/Edit from the visible toolbar — only via
> ⌘N and the inspector. This is the top Phase-7 priority.
- [ ] **Enable the top-level Import / Add / Edit local actions** — replace the module page-title
  `LocalAction.writeStub(...)` placeholders (hardcoded `isEnabled: false`) with live handlers that
  present the Phase-6 `ImportView` / `EntityEditForms` / `WritePreviewView`, in
  `AccountsView`, `AccountGroupDetailView`, `AccountDetailView` (Import/Add/Edit),
  `BudgetCategoriesView` (Add category), `SavingsInvestmentsView` (Add goal), and
  `GoalDetailView` (Edit)
- [ ] **Add the missing "Edit account group" action** — `AccountGroupDetailView` today offers only
  Import/Add, with **no way to edit the group itself** (the affordance is absent, not merely
  disabled). Add an Edit local action on the group screen that opens the existing `EntityEditForms`
  "account group" form → `WritePreviewView`; expose the same entry from the account-group card /
  sidebar group context. (The engine + edit form already support the account-group entity.)
- [ ] Enable the sidebar **"New group"** action (`NavigationSidebarView`, currently `.disabled(true)`)
  and the **empty-state CTAs** (`EmptyStateView` — "add your first account", etc.) to launch the
  matching add form
- [ ] Remove the stale "available with write flows (Phase 6)" help text / `.writeStub` factory once
  every affordance is live; keep only the runtime `WriteGate` disable (with its sync-reason tooltip)
  as the legitimate disabled state (FR-005)
- [ ] Verify parity with the ⌘N command + inspector Edit/Delete so every entity has one consistent
  write entry point; add a smoke test asserting no module ships a permanently-disabled write button

#### Complete Phase 6 write flows (unfinished spec `007` work — folded in from Phase 8)
> The Phase-6 build shipped the write **engine** and most UI but consciously deferred these surfaces
> (was OOS-13…OOS-18 in `docs/out-of-scope-followups.md`, previously routed to Phase 8). Finishing
> them here makes the writable app feature-complete before launch hardening.
- [ ] **OOS-16** — Multi-entry transaction editor UI (`TransactionGroupEditor` + ledger group
  edit/delete). The reconciliation + atomic group-write/delete **engine** shipped and is unit-tested;
  only the SwiftUI authoring surface is missing. Unblocks in-app paycheck/transfer/split entry.
- [ ] **OOS-17** — Interactive per-collection reassignment picker (`ReassignmentPickerView`).
  Delete-with-references never orphans today (defaults to the first available target); this adds
  user choice of reassignment target.
- [ ] **OOS-18** — Budget Markdown-summary export button. `ExportService.budgetSummaryMarkdown`
  exists and is tested; only the in-view action is unwired.
- [ ] **OOS-13** — Per-entity typed edit forms (plan research D10): grouped pickers for
  group/category parents, sign-aware amount fields, enum pickers — replacing the current single
  schema/header-driven `EntityEditForm`.
- [ ] **OOS-14** — Dedicated-screen account edit placement (FR-010): edit in the screen's local
  actions, delete inside the edit flow on `AccountDetailView`. *(Overlaps the Write-affordance
  enablement group above — the account-group Edit action is the same gap; track them together.)*
- [ ] **OOS-15** — Add an optional `description`/memo column to the `transactions` schema
  (non-breaking) so imported bank memos are retained and dedup keys on date+amount+description.
- [ ] Deferred App-target write test suites (Phase-6 T010/T021/T032/T036): WritePreview / Import /
  Reassignment view-models + RepairApply integration — land alongside the Hardening pass below.

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
  - 🟡 Partial — sidebar/table/inspector keyboard nav shipped in Phase 5; audit for full coverage
- [ ] Implement all macOS menu commands: New Workspace, Open Workspace, Reindex Workspace,
  Validate Workspace, Repair Selected Issue, Open Source File, Reveal in Finder, Export Current
  View, Toggle Inspector, Open Backup Folder
  - 🟡 Partial — the §17 `CommandMatrix` (incl. Export ⌘E, Repair ⇧⌘R, New Record ⌘N) shipped in
    Phases 5–6; verify the full command set + wire any remaining (Open Backup Folder)
- [ ] `NSUserActivity` / Handoff: encode navigation state so window restoration after relaunch
  returns to the same view and selection
  - 🟡 Partial — the codec + scene modifiers shipped and are unit-tested in Phase 5; **OS-level
    restoration is only exercisable in the signed app target** — verify end-to-end here
    (OOS-9)
- [ ] Register UTType declarations for `.csv` and `.md` for drag-and-drop import

#### Packaging & Signing
- [ ] Code-sign + notarize the XcodeGen app target (`App/project.yml`) with the
  `iCloud.<bundle-id>` ubiquity-container entitlement; the target builds **unsigned** in CI today —
  signing/notarization are the outstanding developer-machine actions (OOS-1)
- [ ] Real iCloud sync testing on a signed build: edit on one device → observe sync state and the
  update on another; exercise `NSFileVersion` conflict resolution

#### Hardening
- [ ] Comprehensive unit tests for all domain engines against fixture data
  - ✅ Done — `Tests/FinanceWorkspaceKitTests/Unit/*` covers every domain engine; write-engine
    suites live in `WriteEngineTests/`. Remaining: the deferred **App-target** view-model /
    integration suites (Phase-6 T010/T021/T032/T036 — WritePreview/Import/Reassignment/RepairApply)
- [ ] Integration tests for the full read flow: bootstrap → index → parse → validate → project
- [ ] Integration test for each write flow: intent → preview → backup → apply → re-index →
  re-validate
  - 🟡 Partial — engine-level write path covered by `WriteServiceTests`; the App-target
    preview→apply view-model integration tests are the deferred piece
- [ ] Integration test for each auto-repair flow
- [ ] Test against realistic personal finance dataset: 12 months transactions, 3 investment
  accounts, 2 business themes/entities, full deduction set
- [ ] XCUITest automation for the module views (deferred from Phase 5 research D8)

#### Developer Script
- [x] `fixture-generate.swift` — generate a realistic fixture workspace for QA and development
  (seeded with synthetic but plausible data for all file types) — shipped in Phase 1, extended
  through Phases 3–4 to emit every file type
- [ ] `backup-prune.swift` — prune old backups from `.finance-meta/backups/` beyond retention
  limit (depends on the Phase-6 backup retention policy `[DECIDE]`)

### Milestone 7 — Launch Readiness
> **v1 complete.** The app is stable, performant, accessible, signed/notarized, and handles all
> iCloud edge cases gracefully. All domain engines pass their integration test suites against
> realistic fixture data. All write and repair flows are tested end-to-end. The app is ready for
> internal beta or TestFlight distribution.

---

## Phase 8: Out-of-Scope Follow-ups (post-v1 backlog)

**Goal**: Pick up the work that was **in a shipped spec's field of view but consciously deferred
during implementation** — the residue of Phases 1–6. This is a backlog phase, not a milestone-gated
build: items are promoted individually into their own Spec Kit specs (or folded into a future
refinement round) as the PM prioritizes them.

> **Canonical list:** [`docs/out-of-scope-followups.md`](out-of-scope-followups.md) is the source of
> truth (per-item source spec/task, why-deferred, status). The groupings below are the roadmap view.
> Items that are **pure V2** (see the *Out of Scope for v1* table at the top) are **not** in this
> phase — Phase 8 is v1-adjacent residue only.

### Write-flow UI residue (spec `007`, Phase 6) — **moved to Phase 7**

> The unfinished spec-`007` write-flow work (OOS-13…OOS-18 + the deferred App-target write test
> suites) is now folded into **Phase 7** under *Complete Phase 6 write flows*, so the writable app
> is feature-complete before launch hardening. See Phase 7 Development Tasks. These rows remain in
> `docs/out-of-scope-followups.md` for provenance, now tagged for Phase 7.

### Engine & read-model gaps (specs `004`/`005`/`006`)

- [ ] **OOS-4** — Investment/reinvested-gain retained equity: extend the personal-inflow vs
  retained-equity split in `PortfolioEngine`/`TaxEngine` now that trades are modeled (Phase 3
  `AccountEngine` computed only the business portion).
- [ ] **OOS-5** — Populate sleeve-funding links: `LinkingEngine.sleeveLinks`
  (`receiving_asset_id` → `assets.sleeve_id`) yields links once investment trades exist in the ledger.
- [ ] **OOS-7** — Itemized tax-archive read model: `TaxArchiveView` renders closed years as
  raw file previews because the parser skips `Taxes/archive/`; a typed archive projection needs a
  parser/engine extension.
- [ ] **OOS-8** — Account estimates surface: the `AccountEstimate` entity has no
  `WorkspaceContext` accessor / projection, so the per-account "Rules & estimates" panel shows rules
  only. Pairs with the Phase-6 rules/estimates edit flow.
- [ ] Per-account tax allocation refinement: `TaxEngine` effective rate uses ledger withholding legs;
  `estimated-payments.csv` (workspace-level) feeds the estimate, not per-account rates. Acceptable
  for v1; revisit if per-account precision is wanted.

### Validation, repair & write-infra residue (specs `003`/`007`)

- [ ] **OOS-2** — Deferred `RepairService` repair classes: optional-column injection (needs an
  "expected columns" notion), blank-field normalization, and `WriteGate` sync-gating of repair
  writes (FR-016a). The write/sync-gate path built in Phase 6 informs these.
- [ ] **OOS-19** — Pending validation rule predicates (spec `003` T023/T024/T025, marked `[~]`):
  `VAL-FILE-004` (duplicate monthly file), `VAL-CROSS-009` (missing benchmark data), and
  `VAL-DOMAIN-001/002/007/008` (budget period without rows; goal contribution without goal —
  largely covered by CROSS-008; tax payment outside year; business txn with unknown account-group)
  are registered in `RuleCatalog` but have **no predicate wired** — they can never fire. Fix the
  stale `DomainRules.swift` header comment alongside.
- [ ] **OOS-22** — Per-file sync states never reach the write gate: `applyPendingWrite` passes
  `fileStates: [:]` and `WriteService` defaults unknown files to `.available`, so `WriteGate`'s
  per-file refusals (syncing / stale / conflict) are inert in the app — only the workspace-level
  state gates writes. Wire the `NSMetadataQuery` per-file states through `AppState` into apply;
  pairs with OOS-2 and the Phase-7 signed-build sync tests.

### Code-audit findings — 2026-07-06 (source audit, branch `009-out-of-scope-followups`)

- [ ] **OOS-20** — Transfer authoring missing from `TransactionGroupEditor`: the shipped editor
  authors gross → withholdings → net **paycheck** groups only; `MultiEntryLeg.Role` has no
  credit/debit case, so balanced transfers can't be authored in-app. Small additive engine change
  (credit/debit roles) + a transfer mode in the editor.
- [ ] **OOS-21** — Generic per-table "current view" export: ⌘E exports the active module's primary
  file; exporting the *visible rows of any table* (post-filter/sort) is the deferred FR-027
  refinement. `ExportService.csv(rows:columns:)` already accepts arbitrary rows — view-side
  plumbing only.
- [ ] **OOS-23** — Tax tables (`WorkspaceLayout.standardDeduction`/`taxBrackets`) are hardcoded for
  2025/2026 with a **silent latest-year fallback** for any other year. Resolve the open Phase-4
  `[DECIDE]` in `docs/project-management.md` (hardcode per year vs user-editable setting), add an
  annual update procedure + a "no tax table for year N" validation warning.
- [ ] **OOS-24** — `TaxEngine` detects interest income by category-name heuristic
  (`name.contains("interest")`); renamed or non-English categories silently drop interest from the
  tax projection. Typed category flag (future schema round) or a documented naming convention +
  validation rule.

### QA residue (spec `006`, Phase 5)

- [ ] **Flow 9 manual demo pass** — the Milestone-5 interactive walkthrough (`docs/test-plans.md`
  Flow 9: keyboard nav, dark mode, traceability) is still **[Manual pass pending]**; the automated
  proofs passed. PM action — may be absorbed by the Phase-7 XCUITest + quickstart runs.

### PM-requested enhancements (post-v1)

- [ ] **Manual re-ordering of accounts and account groups in the sidebar** *(added 2026-07-07)* —
  let the user drag-reorder the account groups and the accounts within each group in the sidebar's
  "Account groups" section (`NavigationSidebarView`), instead of the current fixed ordering.
  Persistence should follow plain-files-first (constitution #1): an **optional `sort_order` column**
  on `accounts.csv` / `account-groups.csv` (additive, non-breaking per the §21 migration policy) so
  the order syncs with the workspace and stays user-editable in Finder — not a device-local pref.
  Reorder writes go through the safe-write path; absent values fall back to the current default
  order. Touches: schema round (2 optional columns), `AccountEngine` projection ordering,
  sidebar drag-and-drop (`.onMove`/`.draggable`), and the group/account card grids that mirror
  sidebar order.
- [ ] **Delete action inside the edit modal for accounts, account groups, and categories**
  *(added 2026-07-07)* — the `EntityEditForm` sheet currently offers save/cancel only; deletion is
  reachable only from the detail-pane bottom buttons. Add a Delete action to the edit modal for
  these three entities so edit → delete is one flow (destructive placement per the locked
  edit/delete convention: "delete inside the edit flow"). Must route through the existing
  delete-with-reference-check path (`requestDelete` → `ReferenceScanner` → atomic
  delete + reassignment plan → write preview) — never a bare row delete. Overlaps **OOS-14**
  (FR-010 dedicated-screen account edit placement, scheduled Phase 7) and benefits from
  **OOS-17**'s interactive reassignment picker — track together when speccing.

### Deferred to V2 (tracked, not in Phase 8)

These surfaced during the build but are genuinely V2 — they stay in the *Out of Scope for v1* table
and are listed here only so the trail is unbroken:

- **Sector-vs-benchmark comparison** — `benchmarks/sp500.csv` carries only `date,close`; benchmark
  sector data is a future schema round (`BenchmarkEngine` reports portfolio sector weights only).
- **Live price ingestion** — prices/benchmark come from static CSVs; live ingestion stays V2.

### Milestone 8 — Backlog burndown (no fixed gate)
> Phase 8 has no single completion gate. Each promoted item ships as its own increment; the phase
> is "done" when the PM has triaged every open row in `docs/out-of-scope-followups.md` to
> shipped / rescheduled / won't-do.

---

## Summary Table

| Phase | Focus | Key Deliverable | Prerequisite | Status |
|---|---|---|---|---|
| 1 | Foundation & Architecture | Workspace resolves, files indexed, models defined | — | ✅ merged (PR #15) |
| 2 | Parsing & Validation | All file types parsed, validation engine live | Phase 1 | ✅ merged (PR #16) |
| 3 | Domain I — Accounts, Budget, Overview | Core projections, master account registry | Phase 2 | ✅ merged (PR #18) |
| 4 | Domain II — S&I, Tax | All domain engines functional | Phase 3 (AccountEngine) | ✅ merged (PR #19) |
| 5 | Presentation — Shell & All Views | Full UI connected to domain projections | Phase 3 + 4 | ✅ merged (PR #20) |
| 6 | Write Flows, Repair & Export | App is writable, repair is guided | Phase 5 | ✅ merged (PR #21) |
| 7 | Polish & Launch Readiness | Finish Phase-6 write flows + performance, accessibility, signing, test coverage | Phase 6 | 🔵 active (`008-polish-launch`) |
| 8 | Out-of-Scope Follow-ups | Engine/read-model + repair-infra residue backlog | Phases 2/4/5 (residue) | ⚪ backlog |

---

## Open Decisions (Pre-Build)

All Phase 1 architectural decisions have been locked as of 2026-06-10. See `docs/technical-design.md §21` for the full locked-decision record.

| Decision | Resolution |
|---|---|
| `CloudStorageProvider` protocol surface | Minimum surface confirmed: `resolveWorkspaceURL()`, `syncState`, `isAvailable`. Conflict resolution stays iCloud-specific. |
| Master registry vs investment accounts | Unified `Accounts/accounts.csv` with optional investment columns. No separate `Investments/accounts.csv`. |
| Savings/ and Investments/ folder separation | Keep separate at the file level. |
| Deductions file structure | **Reopened & resolved (Round 6):** renamed to `Taxes/tax-adjustments.csv` with an `adjustment_type` union enum; Tax-adjustment is a first-class object. |
| Round 6 object-model reconciliations | **Resolved (2026-06-23):** kept two-tier `account_group`+`account_type`; `status` canonical (`is_active` derived); categories add `parent_category_id`+`category_group_id`; assets add `security_class`; trades fold into the unified ledger; `adjustment_type` = union enum. |
| Tax year-close trigger | Explicit in-app "Close Tax Year" action only. |
| Right pane default-closed scope | Global — closed by default, opens on main-panel interaction, no section exceptions. |
| iCloud container identifier | `iCloud.com.<org>.OpenFinance` (R8 — corrected from bare `OpenFinance`) |
| Workspace bootstrap seed accounts | Personal bank, personal credit card, business bank, business credit card, savings, investment |
| Default delete behavior when an object is referenced | **Locked Round 7** — reassign: surface referencing rows, present per-collection reassignment picker, write delete + reassignments atomically. See `docs/product-requirements.md §12`. |

---

## Changelog

> The roadmap participates in the same round-numbered refinement loop as the PRD and technical
> design. Rounds are global across all three docs; see `docs/_refinement/r{N}-*` for the source
> review and per-doc update plans.

### Backlog addition — 2026-07-07 (PM request)
- **Phase 8 gained a *PM-requested enhancements* grouping** with its first row: manual
  drag-re-ordering of accounts and account groups in the sidebar "Account groups" section,
  persisted as an optional `sort_order` column on `accounts.csv`/`account-groups.csv`
  (plain-files-first; additive/non-breaking) rather than a device-local preference.
- **Second row: Delete inside the edit modal** for accounts, account groups, and categories —
  `EntityEditForm` gains a Delete action (destructive, "delete inside the edit flow" per the
  locked convention) routed through the existing delete-with-reference-check/reassignment path;
  overlaps OOS-14, pairs with OOS-17.

### Backlog sync — 2026-07-06 (spec 002–008 review + code audit; branch `009-out-of-scope-followups`)
Not a refinement round — a Phase-8 backlog expansion after reviewing the task state of specs
002–008 and auditing the app source. Canonical per-item detail: `docs/out-of-scope-followups.md`.

- **Spec review**: all residue from specs `002`, `007`, and `008` was already tracked (Phase 7 /
  OOS-1, OOS-13…18); specs `004`–`006` residue was already in Phase 8 (OOS-4/5/7/8). The one gap:
  spec `003`'s three partially-delivered rule tasks left **six registered-but-inert validation
  rules** (catalog metadata, no predicate) → new **OOS-19**.
- **Code-audit findings** (new): transfer authoring missing from `TransactionGroupEditor`
  (**OOS-20**), generic current-view export not wired (**OOS-21**), per-file sync states never
  reach `WriteGate` in the app write path (**OOS-22**), hardcoded 2025/2026 tax tables with a
  silent latest-year fallback (**OOS-23**, ties to the open Phase-4 `[DECIDE]`), and the
  interest-income category-name heuristic in `TaxEngine` (**OOS-24**).
- Phase 8 gained a *Code-audit findings* grouping and a *QA residue* row (the spec-`006` Flow 9
  manual demo pass, previously tracked only in `docs/test-plans.md` / the OOS doc); the spec-`003`
  grouping widened to *Validation, repair & write-infra residue* to hold OOS-19/OOS-22.

### Build-status sync — 2026-07-06 (Phases 4–6 merged; Phase 7 active; Phase 8 added)
Not a refinement round — a doc-to-repo alignment recorded after Phases 4–6 land on `main`.

- **Phases 4, 5, and 6 marked COMPLETE and merged** (PRs #19/#20/#21). Phase 4 (`005`) and Phase 5
  (`006`) status banners flipped from "🟡 pending CI + merge" to "✅ merged"; a **new Phase 6 (`007`)
  status banner** records the writable-app delivery (one Kit-level write engine composing the
  Phase-1 safe-write primitives; US1/US2/US4/US5/US6 shipped + CI-tested; US3 multi-entry engine
  shipped). Milestone 6 marked reached.
- **Phase 6 UI residue captured**: multi-entry editor (OOS-16), reassignment picker (OOS-17), Budget
  Markdown export button (OOS-18), D10 typed forms (OOS-13), account-edit placement (OOS-14),
  optional `transactions.description` column (OOS-15) — initially routed to Phase 8, then **moved to
  Phase 7** (see below). The `007` series was renumbered OOS-13…OOS-18 in
  `docs/out-of-scope-followups.md` to end the collision with the `006` series OOS-7/8/9.
- **Phase 7 (Polish & Launch Readiness) rewritten for current state**: added a 🔵 ACTIVE banner
  (branch `008-polish-launch`), annotated tasks already satisfied by Phases 1–6 (✅ domain-engine
  unit tests, ✅ `fixture-generate`; 🟡 keyboard nav, command matrix, `NSUserActivity` codec), and
  added an explicit **Packaging & Signing** subsection (code-sign + notarize the app target — OOS-1;
  real iCloud sync on a signed build) plus an XCUITest item.
- **New Phase 8 — Out-of-Scope Follow-ups**: a post-v1 backlog phase mirroring
  `docs/out-of-scope-followups.md` (write-flow UI residue, engine/read-model gaps, repair/write-infra
  residue), with pure-V2 items (sector-vs-benchmark data, live price ingestion) explicitly kept out.
- **Unfinished Phase-6 write-flow work moved from Phase 8 into Phase 7** (new *Complete Phase 6
  write flows* subsection): OOS-13…OOS-18 (multi-entry editor, reassignment picker, Budget-MD export
  button, typed forms, account-edit placement, `transactions.description` column) + the deferred
  App-target write test suites. Phase 8 now holds only the engine/read-model + repair-infra residue
  and pure-V2 items; the Phase 6/7/8 banners, Milestone 6, and summary table were resynced.
- **Phase 7 gained a "Write-affordance enablement" task group (do-first)** after finding that the
  running app still shows the **top-level Import/Add/Edit buttons disabled** — Phase 6 shipped the
  write engine + ⌘N + inspector Edit/Delete + preview/form views but never converted the module
  page-title `LocalAction.writeStub(...)` placeholders (hardcoded `isEnabled: false`) to live
  handlers. Captured in the Phase 7 status banner + a concrete per-view task list. (Overlaps and
  subsumes OOS-14, the dedicated-screen account-edit placement.) The same task group adds the
  **missing "Edit account group" action** — `AccountGroupDetailView` has no group-edit affordance at
  all (absent, not just disabled), though the engine + `EntityEditForms` already support it.
- **Dependency overview, summary table, and status column** updated; the top-of-doc "Last updated"
  line now reflects Phases 1–6 complete.

### Build-status sync — 2026-06-30 (Phase 3 build complete on branch)
Not a refinement round — a doc-to-repo alignment recorded as the Phase 3 implementation lands on
`004-domain-accounts-budget-overview` (pending CI + merge).

- **Phase 3 marked BUILD COMPLETE on branch** (spec `004-domain-accounts-budget-overview`, 39/39
  tasks; **Milestone 3** reached). Added a 🟡 status banner at the top of Phase 3 and annotated the
  Milestone 3 callout.
- **Domain Layer I delivered:** record-mapping seam (`ParsedRecord`→typed entities), `AccountEngine`,
  `BudgetEngine`, `LinkingEngine`, `OverviewEngine`, expanded seed (16 categories / 6 groups +
  default Household budget), and the `accounts-overview` / `budget-overview` / `overview-dashboard`
  CLIs. Engine math (retained-equity split, withholding-as-taxes, partial trailing averages,
  gap-skipping MoM, stubbed Investments/Taxes cards) verified via the CLIs; full test + lint gate
  runs in macOS CI.
- **`[FIX-C2]` retired** (roadmap Phase-3 dependency note already carried the correct paths) and the
  Phase-3 product `[DECIDE]`s resolved in the spec; `docs/project-management.md` updated.
- **Living docs updated:** `docs/out-of-scope-followups.md` (OOS-4/5/6 — Phase-4 retained equity &
  sleeve links, Phase-5 UI + estimated-rate) and `docs/test-plans.md` (projection CLIs now testable).
- **Next:** push → CI → PR/merge; then **Phase 4 (Domain Layer II — Savings, Investments & Tax)**.

### Build-status sync — 2026-06-30 (Phase 2 complete & merged)
Not a refinement round — a doc-to-repo alignment recorded as Phase 2 completes.

- **Phase 2 marked COMPLETE** (merged to `main`, PR #16; spec `003-parsing-validation`, all 43
  tasks; Milestone 2 gate confirmed at T043). Added a status banner at the top of Phase 2.
- **Parsing + Validation layer delivered:** `CSVParserService` / `CSVSchemaRegistry` /
  `CSVNormalizer` / `FrontMatterParser` / `MarkdownParserService` / `WorkspaceParser`,
  `ValidationEngine` + `RuleCatalog` (34 rules: 15 file / 11 cross-file / 8 domain), `RepairService`,
  `SettingsStore`, `MigrationService`, and the `validate-workspace` / `repair-workspace` /
  `migrate-r6` CLIs.
- **Schemas bundled:** 23 canonical JSON schemas live in
  `Sources/FinanceWorkspaceKit/Resources/Schemas/` (loaded via `Bundle.module`) and mirror into the
  workspace `.finance-meta/schemas/` at bootstrap.
- **Project-management sync:** the two partially-resolved Phase 2 `[DECIDE]`s (CSV spec gaps,
  validation rule catalog) and all five `R6-M1…M5` `[FIX]`s retired; item-count table updated.
- **Phase 3 (Domain Layer I — Accounts, Budget & Overview)** is the next phase — not yet started.

### Build-status sync — 2026-06-28
Not a refinement round — a doc-to-repo alignment recorded as Phase 2 begins.

- **Phase 1 marked COMPLETE** (merged to `main`, PR #15; spec `002-foundation-architecture`, 49/50
  tasks). Added a status banner at the top of Phase 1.
- **Packaging reality recorded:** foundation built as a **Swift Package** (`FinanceWorkspaceKit`
  library + `FinanceWorkspaceApp`/`bootstrap-workspace`/`fixture-generate`/`index-check`
  executables), not a hand-authored `.xcodeproj`; module folders map to
  `Sources/FinanceWorkspaceKit/{Platform,Domain,Validation,Persistence,Parsing}/`. The "Xcode
  Project Setup" tasks were realized via SwiftPM.
- **macOS CI landed early:** `ci-macos.yml` (`swift build`/`swift test`) shipped in Phase 1
  alongside the Linux SwiftLint runner; supersedes the "full Mac build CI deferred to Phase 5"
  note.
- **One Phase 1 item deferred:** the iCloud ubiquity-container entitlement + dev code signing
  (needs the Xcode app target).
- **Phase 2 started** on branch `003-parsing-validation` (spec `specs/003-parsing-validation`).

### Round 8 — 2026-06-26
Source: `docs/_refinement/r8-review.md` (foundation hardening — Phase 1–2 dev-env / storage / sync)

- **New Phase 0 sub-track** (env bootstrap: entitlement, DEBUG local-folder provider, `fixture-generate`, CI smoke test for dual-mode workspace resolution, JSON schema authoring).
- **Phase 1 Platform tasks** reworded: `ICloudContainerService` (NSMetadataQuery sync state, `NSFileVersion` conflicts, `iCloud.<bundle-id>` ID), `FileWatcherService` (NSMetadataQuery + FSEvents), `ManifestStore` (device-local Application Support location).
- **Phase 1 Product tasks** for entitlement / 7 sync states / manifest shape marked resolved (R8).
- **Core Data Models**: removed `OwnerDistribution`; `Account` = single struct + optional `InvestmentMetadata?`.
- **Phase 2**: schema_version comment-row + JSON schemas as source of truth; sign-flip = explicit per-import declaration; validation rule-catalog shape + classification defaults adopted; `goals.csv status ∈ {active, archived}`; `savings-goal-contributions.csv` removed.
- **Spec-review follow-up (2026-06-26):** Phase 1 Core Data Models gained `AccountGroup` (first-class R6 object, `account_group_id` FK) and the `BusinessMonthlySummary` cross-domain projection. Schema-count wording reconciled ("28" → one schema per managed file type). Surfaced during the `specs/002-foundation-architecture` review.

### Round 7 — 2026-06-24
Source: `docs/_refinement/r7-review.md` (MVP prep — doc-sync debt + direction decisions B1–C5)

**Section A — doc-sync debt:**
- Out of Scope: added "Live price ingestion strategy" as an explicit V2 tracked item (A5)
- Phase 2: R6 migration tasks promoted to explicit `[FIX]` items in `docs/project-management.md` (`R6-M1` through `R6-M5`); prototype path-fix task added as `[FIX – R7-P1]`
- Phase 6 Design: added prototype update task for write/edit flow demos
- `docs/technical-design.md` refactored to a lean overview with links to `docs/architecture/` (A3)
- `docs/architecture/data-pipelines.md` §3 adds four ingestion pipeline diagrams (A4)
- `prototype/data.js` stale file paths corrected (A2)
- `docs/project-management.md`: resolved items C1, C5, S8 retired; R6 migration tasks added (A1)

**Section B/C — direction decisions:**
- Open Decisions: delete-on-reference locked as **reassign** (B1); Business module locked as **group type under Accounts** — no standalone BusinessEngine (B3); Markdown viewer/editor locked as **V2** (B4)
- `docs/product-requirements.md`: §4 Markdown V2, §8 tax scope guardrail, §12 reassign delete policy, NFR Performance M1+ target, NFR Reliability sync-first write safety (C1)
- `docs/architecture/core-domain.md §3`: sync-first write gate documented on ICloudContainerService; Business module note updated to resolved
- `docs/technical-design.md §21`: locked decisions added for B1/B3/B4/C1/C2/C5
- `docs/project-management.md`: [FIX-S1], [FIX-C3], [FIX-S2] retired

### Round 6 — 2026-06-23
Source: `docs/_refinement/r6-review.md` (fourth prototype review — data structuring & IA); update plan `docs/_refinement/r6-update-product-roadmap.md`

- Phase 1: Core Data Models and bootstrap updated for the renamed + new files (account-groups, liabilities, assets, portfolios, budget-allocations, tax-adjustments, tax estimates/documents) and the multi-entry transaction columns
- Phase 2: added multi-entry group validation; added `migrate-r6.swift` (preview-able schema migration that also folds `Investments/transactions.csv` into the unified ledger)
- Phase 3: AccountEngine derives liability balances; BudgetEngine resolves a Budget's scope over its allocations
- Phase 4: PortfolioEngine gains the Portfolio container; investment trades fold into the unified ledger; `TaxAdjustmentEngine` replaces `DeductionEngine` (adds tax-estimates + tax-documents)
- Phase 5: account screens surface assets and liabilities; Portfolio views; new multi-entry transaction editor
- Phase 6: multi-entry groups written atomically
- Open Decisions: reopened+resolved the deductions-file decision; recorded the Round 6 reconciliation resolutions *(delete-on-reference locked Round 7: reassign)*
- Overrides the r5 object-model audit where they differ (Portfolio not Strategy, `account_group_id` not `group_id`, no group nesting) — r6-review takes priority

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
