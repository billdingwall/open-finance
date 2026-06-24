# Pre-Build Items

**Generated**: 2026-06-10  
**Last updated**: 2026-06-24 (Round 7 extended — added dev environment DECIDE items: macOS deployment target, Xcode/Swift version, CI/CD pipeline, Figma MCP handoff policy; CLAUDE.md toolchain documented)  
**Sources**: `docs/_notes/consistency-audit.md` · `docs/_notes/open-decisions.md`  
**Purpose**: Single consolidated reference of every outstanding item before and during each build phase. Replaces both source documents for day-to-day use.

---

## Item types

| Tag | Meaning |
|---|---|
| **[FIX]** | A documented inconsistency across PRD, technical design, or roadmap that needs to be corrected. No new decision required — just a doc update. Audit ID shown in parentheses. |
| **[DECIDE]** | An open question requiring a choice before implementation can proceed. |

---

## Phase 1 — Foundation & Architecture

### Product

~~**[FIX – C3]** Decide whether Business is a standalone module or a theme under Accounts~~ **Resolved R7** — Business is a `group_type = business` account group, managed through the account-group system. No standalone BusinessEngine. All business P&L logic lives in `AccountEngine`. `docs/architecture/core-domain.md §2–3` updated; no `Domain/Business/` subfolder in the module layout.

~~**[FIX – S1]** Clarify whether inline Markdown rendering is in v1 scope~~ **Resolved R7** — `docs/product-requirements.md §4` updated: Markdown viewer/editor is V2. In v1, Markdown files are parsed for front matter metadata only; no body rendering in the app UI. Consistent with the out-of-scope list and roadmap.

~~**[FIX – S8]** Mark "advanced workspace mode" as V2 in Tech Design §5~~ **Resolved R7** — `docs/technical-design.md §5` advanced workspace mode is now marked as V2 only.

**[FIX – S9]** Add display name → enum value mapping for account groups  
PRD §5 uses "Everyday Banking" and "Loans & Debt" as group display names. Tech Design §8.21 enum uses `checking` and `loan`. No mapping exists between the two. Add a mapping table to PRD §5 or Tech Design §8.21: "Everyday Banking" → `checking`, "Loans & Debt" → `loan`, "Credit Cards" → `credit_card`.

**[FIX – S5]** Decide whether `OwnerDistribution` is in scope for v1  
PRD data model and Roadmap Phase 1 both list `OwnerDistribution` as an entity to define. Tech Design §10 does not include it. No CSV spec exists. Either add it to Tech Design §10 and create a §8 CSV spec, or remove it from the PRD data model and the Roadmap Phase 1 entity list.

**[FIX – M5]** Align AI integration language  
PRD non-goals says "AI model integrations to analyze performance" with no timeline (implying never). Roadmap out-of-scope says "AI-driven analysis or recommendations — V2." Update PRD non-goals to say "V2 deferred" to match the roadmap.

**[DECIDE]** iCloud entitlement strategy — what provisioning profile and signing approach is used for development vs distribution? Is a separate development container needed, or is one identifier (`OpenFinance`) used across both environments?

**[DECIDE]** 7 iCloud sync states — for each state below, what is the UI treatment? Options per state: persistent toolbar badge, full-screen blocking prompt, dismissible banner, per-file row indicator, or no indicator.
- Available
- Not signed into iCloud
- Container unavailable
- Syncing
- Local copy stale
- File missing locally
- Conflict detected

**[DECIDE]** `manifest.json` per-file field set — which fields are stored per-file entry? Minimum candidate: path, domain classification, `schema_version`, SHA-256 hash, last-indexed timestamp, last validation result summary. Are per-file sync state or repair history included here, or tracked separately?

---

### Design

**[DECIDE]** Figma → code handoff policy — with Figma MCP tooling in the stack, what does the MCP server expose to the AI assistant (design tokens, component specs, layer annotations, asset URLs)? What naming conventions apply for tokens and components? Which assets are committed to `docs/_design/` versus read live from Figma at implementation time? Document MCP server configuration in `.claude/settings.json` and `CLAUDE.md` once finalized.

**[DECIDE]** First-launch onboarding flow — workspace creation screens, iCloud availability states, fallback UI when iCloud is unavailable

**[DECIDE]** Workspace sync status indicators — persistent status bar element design, per-file sync badge design for all 7 sync states

**[DECIDE]** Loading/indexing state — what the user sees between launch and when projections are ready (skeleton screens, progress indicator, or blocking state)

**[DECIDE]** Global app shell skeleton — window chrome, toolbar layout, menu bar structure, empty navigation state

---

### Development

~~**[FIX – C1]** Remove `InvestmentAccount` from Tech Design §10 entity list and Roadmap Phase 1 entity task~~ **Resolved R4** — `InvestmentAccount` removed; investment fields are optional properties on `Account`. `docs/architecture/core-domain.md` reflects this.

~~**[FIX – C5]** Correct the manifest JSON example path in Tech Design §9~~ **Resolved R7** — `docs/technical-design.md §9` manifest example updated to `Accounts/transactions/2026-05.csv` / `"domain": "accounts"`.

**[FIX – C6]** Rename `BusinessEntity` to `Entity` or `WorkspaceEntity` in Tech Design §10  
`BusinessEntity` is the current entity name in §10, but the type covers personal, employment, business, and custom entities — not just business. Rename to `Entity` or `WorkspaceEntity` throughout §10 and any service descriptions that reference it.

~~**[FIX – S2]** Add a `BusinessEngine` service description to §12, or remove it from §11~~ **Resolved R7** — `BusinessEngine.swift` removed from module layout; business P&L is part of `AccountEngine`. See [FIX-C3] resolution above.

**[FIX – S6]** Add service descriptions for `FileCoordinatorService`, `ManifestStore`, and `SettingsStore`  
All three appear in the Tech Design §11 module layout but have no entries in §12 service responsibilities. `FileCoordinatorService` wraps `NSFileCoordinator` for iCloud-safe reads and writes — non-trivial and needs a service spec. `ManifestStore` and `SettingsStore` are named in roadmap build tasks but have no §12 definition.

**[FIX – M1]** Align layer count across documents  
PRD describes 4 layers, CLAUDE.md 5 layers, Tech Design 6 layers. These are different decompositions of the same architecture. Add a note to Tech Design §3 that the PRD 4-layer model is a simplified view, or update all documents to use the same count.

**[FIX – M2]** Remove `ReportingEngine` from PRD core modules  
PRD Technical Architecture lists `ReportingEngine` in the Domain Layer. It does not exist in Tech Design §11 or §12 — its functionality is covered by `ExportService` (Phase 6) and domain engine projections. Remove from PRD or replace with `ExportService`.

**[FIX – M3]** Reconcile PRD data model entities with Tech Design §10  
~13 PRD entities have no Tech Design §10 counterpart or use different names. Key examples:

| PRD entity | Tech Design equivalent |
|---|---|
| `GoalContribution` | `savings_goal_id` field on transactions |
| `GoalStatusSnapshot` | `SavingsProgress` |
| `Security` | ticker reference on `Holding` |
| `Lot` | `Trade` + `tax-lots.csv` |
| `RealizedGain`, `IncomeEvent` | Derived from `Trade` records |
| `TaxPrepIssue`, `ImportIssue` | `ValidationIssue` |
| `BenchmarkSeries` | `BenchmarkPeriod` |
| `MonthlyReview`, `StrategyNote` | Subtypes of `NoteDocument` |
| `SchemaVersion`, `Merchant`, `BudgetContribution` | Fields, not entities |

Update the PRD data model table to match §10 naming, or add a mapping note.

**[FIX – M4]** Align MVVM vs Observation language  
PRD recommends "MVVM for presentation logic." Tech Design §11 says "Observation for app state and model updates" with no mention of MVVM. Add a note to Tech Design §11 confirming MVVM as the view model pattern, or update the PRD to say "Observation-based state management."

**[FIX – M6]** Replace `PersonalTransaction` / `BusinessTransaction` with `Transaction`  
Tech Design §10 and Roadmap Phase 1 list both `PersonalTransaction` and `BusinessTransaction` as separate entity types. The file model uses a single unified transaction file; personal vs business filtering is done at query time by `entity_id` and `account_group`. Replace with a single `Transaction` or `UnifiedTransaction` entity in §10 and the Phase 1 roadmap entity list.

**[DECIDE]** macOS deployment target — what is the minimum macOS version for `FinanceWorkspaceApp`? Constraint: `@Observable` (Observation framework) requires macOS 14 (Sonoma). Given the M1+ hardware baseline (C2, locked R7), macOS 14 is the likely minimum. Candidates: macOS 14 (Sonoma) or macOS 15 (Sequoia). Decision gates Xcode project creation and determines which SwiftUI, Swift Charts, and Observation APIs are available across all phases.

**[DECIDE]** Xcode and Swift version requirements — which Xcode version is required for development? Which Swift language version? These must be pinned for reproducible builds across Claude Code, Antigravity IDE, and CI. Document the answers in `CLAUDE.md` and `docs/technical-design.md §2`.

**[DECIDE]** CI/CD pipeline — what runs on pull request? Options: (a) SwiftLint + doc/script checks on a Linux runner only (no Mac build check); (b) full Swift build on a self-hosted Mac runner; (c) defer build CI to a later phase. How are code signing and iCloud entitlements handled in a CI environment that has no Apple Developer account?

**[DECIDE]** `FileWatcherService` implementation — `DispatchSource` (lower-level file descriptor watching) vs `NSFilePresenter` (higher-level, integrates with iCloud file coordination)?

**[DECIDE]** `Account` model shape — single struct with optional investment fields, or a base `Account` type and an `InvestmentAccount` subtype that `PortfolioEngine` uses?

---

## Phase 2 — Parsing, Validation & Infrastructure

### Product

**[FIX – S4]** Decide the purpose of `savings-goal-contributions.csv` or remove it  
Tech Design §6 workspace folder structure lists `Budget/savings-goal-contributions.csv`. No §8 spec exists. It is not referenced in §12 service descriptions or §16 UI requirements. May be superseded by the `savings_goal_id` column on `Accounts/transactions/YYYY-MM.csv`. Either create a §8 spec defining its purpose and columns, or remove it from §6 and confirm `savings_goal_id` is the sole budget-to-goal linking mechanism.

**[FIX – S7]** Define the savings goal `status` enum values  
Tech Design §8.5 lists `status` as an `enum` column with no defined values. The Roadmap Phase 4 design task assumes an "archived" state. Without defined enum values, `SavingsGoalEngine` and `GoalsListView` cannot be built consistently. Add values to §8.5 — candidates: `active`, `paused`, `completed`, `archived`.

**[DECIDE]** CSV spec gaps — the 24 file specs in Tech Design §8 need the following completed before `CSVSchemaRegistry` can be built:
- Enum value sets for `account_group`, `account_type`, `trade_type`, `frequency`, `deduction_type`, `status`
- Which columns in each spec are required vs optional at parse time
- Whether `schema_version` is a CSV comment row, a standard column, or manifest-only — one format, applied consistently

**[DECIDE]** Validation rule catalog — all rules across three tiers (file-level, cross-file, domain) need: a rule ID, severity (error / warning / info), and repair classification (auto / manual / none). This catalog does not yet exist in any document and must be written before `RuleCatalog` can be implemented.

**[DECIDE]** Validation issue classification — for each rule, decide:
- Is a missing optional column an error or a warning?
- Is an unknown `category_id` reference an error or a warning?
- Is an unknown `account_id` on a transaction row auto-repairable (prompt to add account) or manual-only?
- Is a missing required folder auto-repairable (create it) or a blocking error?

---

### Design

**[DECIDE]** Validation issue card — icon and color system by severity, card layout (file path, issue text, remediation hint, repair vs manual badge)

**[DECIDE]** Repair preview panel — diff-style before/after row view, backup confirmation step, apply/cancel controls

**[DECIDE]** Indexing progress state — file count display, hash progress indicator, classification warnings surfaced during scan

---

### Development

**[DECIDE]** `schema_version` header format — stored as a CSV comment row (e.g. `# schema_version: 1`), as a dedicated first column on data rows, or tracked only in the manifest? `CSVParserService` and `CSVSchemaRegistry` must agree.

**[DECIDE]** Import sign-flip detection — how does `CSVNormalizer` detect that a source file uses the opposite sign convention? Options: explicit user confirmation in the column-mapping step, a heuristic (if most expense amounts are positive, flip), or always ask the user to declare the source sign convention per import.

**[FIX – R6-M1]** Apply R6 schema renames in `CSVSchemaRegistry`  
Three file/column renames from Round 6 must be reflected in the schema registry before parsing can be built: `entities.csv` → `account-groups.csv` (FK column `entity_id` → `account_group_id`); `holdings.csv` → `assets.csv` (FK column `holding_id` → `asset_id`); `deductions.csv` → `tax-adjustments.csv` (FK column `deduction_id` → `tax_adjustment_id`). All specs are in `docs/architecture/containers-and-budgets.md §3`.

**[FIX – R6-M2]** Add `Accounts/liabilities.csv` spec to `CSVSchemaRegistry`  
`Liability` is a first-class object as of Round 6 — `Accounts/liabilities.csv` was added. The schema registry must include this file. Spec is in `docs/architecture/containers-and-budgets.md §3.3`.

**[FIX – R6-M3]** Add `Investments/portfolios.csv` and sleeve files to `CSVSchemaRegistry`  
`Portfolio` was introduced as a formal investment container in Round 6 — `Investments/portfolios.csv`, `Investments/sleeves.csv`, and `Investments/sleeve-targets.csv` were added. The schema registry must include all three. Specs are in `docs/architecture/containers-and-budgets.md §3`.

**[FIX – R6-M4]** Add `group_id` and `group_role` columns to the unified transaction schema  
Multi-entry transactions (transfers, paycheck gross/net splits) use a shared `group_id` connector and a `group_role` column (`gross`, `net`, `withholding`, `credit`, `debit`). These columns must be in the `Accounts/transactions/YYYY-MM.csv` spec in `CSVSchemaRegistry`. Spec is in `docs/architecture/containers-and-budgets.md §3.1`.

**[FIX – R6-M5]** Create one-time `migrate-r6.swift` migration script  
Before first build, a preview-able migration script is needed to rename the three legacy CSV files (`entities.csv` → `account-groups.csv`, `holdings.csv` → `assets.csv`, `deductions.csv` → `tax-adjustments.csv`), update FK column names in-place, and fold `Investments/transactions.csv` into the unified monthly ledger. Spec is in `docs/architecture/data-pipelines.md §2` (optional scripts). Existing workspaces from the prototype era will need this path.

**[FIX – R7-P1]** Update prototype `data.js` write/edit flows  
The prototype does not yet demonstrate edit and delete interactions. Roadmap tasks for write flows (Phase 6) should include updating the prototype to show: add transaction modal, edit account side panel, delete with reference preview, import CSV column-mapping flow. Tracked per `docs/_refinement/r7-review.md` item B1.

---

## Phase 3 — Domain Layer I: Accounts, Budget & Overview

### Product

**[FIX – C2]** Correct the Phase 3 critical dependency note in the roadmap  
The note currently reads: "`Investments/accounts.csv`, `Business/entities.csv`, and all transaction files reference `account_id` from the master registry." Both paths are wrong. `Investments/accounts.csv` was removed by the unified accounts decision; the master registry is `Accounts/accounts.csv`. `Business/entities.csv` has never existed; the file is `Accounts/entities.csv`. Update the note to reference the correct paths.

**[DECIDE]** Account type taxonomy — the `account_group` enum has 7 groups. What are all valid `account_type` sub-types within each? For example:
- `checking`: personal, joint
- `savings`: HYSA, standard, money market
- `investment`: taxable brokerage, Roth IRA, Traditional IRA, HSA, 401k, SEP-IRA
- `credit_card`: personal, business
- `loan`: mortgage, auto, personal, student
- `employment`: W-2 payroll, 1099 contract
- `business`: sole proprietor, LLC, S-Corp

**[DECIDE]** Default budget category set — group names, category names, `default_budget_behavior` (fixed / discretionary / savings / investment / transfer), and `tax_relevant` flag for each. This is the seed data written by `bootstrap-workspace` and shown to every new user.

**[DECIDE]** Entities/themes taxonomy — display labels, icon identifiers, and which account groups are valid under each of the four entity types (personal, employment, business, custom). Can a user have more than one employment entity (e.g. two jobs)?

**[DECIDE]** 3-month trailing average — sparse data: when fewer than 3 full months exist, show a partial average with a data-sufficiency label (e.g. "avg of 1 mo"), dashes until 3 months exist, or the available data with no special treatment?

**[DECIDE]** Overview KPI card field specs — exact field definitions for all 5 cards:
- **Budget**: "estimated spending" — sum of all budget plan rows, or actual-to-date with a projection for remaining days?
- **Savings**: "estimated rate" — account yield from account rules, or YTD growth rate from balance snapshots?
- **Investments**: "estimated rate" — YTD portfolio return, annualized benchmark return, or yield from account rules?
- **Business**: which entities are included — all `entity_type: business`, or only active ones?
- **Taxes**: "estimated return" — derived by `DeductionEngine` (taxes_paid − estimated_owed), or user-entered?

**[DECIDE]** Month-over-month panel — how many prior months are shown (3, 6, or 12)? When a month has no data, show a zero bar, a gap, or skip the month?

**[DECIDE]** YTD net income formula — `gross_income − total_expenses − taxes_paid` defined per account group:
- `employment`: gross = all positive transactions; what counts as expenses? What counts as taxes paid?
- `business`: gross = revenue; expenses = business expense transactions; taxes = estimated payments for the entity?
- `checking`: gross = deposits; expenses = debits excluding transfers?
- How are inter-account transfers excluded from both sides?

---

### Design

**[DECIDE]** Accounts overview — card grid layout, card anatomy (institution name, account type badge, monthly cash inflow, YTD net income), aggregate header row

**[DECIDE]** Per-account detail — chart type for monthly gross vs expenses/tax, YTD figures layout, transaction list within account context, account rules panel

**[DECIDE]** Budget overview — pie chart breakdown (fixed / discretionary / savings / investments as % of net income), category table column set (plan / actual / variance / 3-month average), period selector

**[DECIDE]** Budget history — view type (table vs bar chart), period range selector

**[DECIDE]** Overview dashboard — 5 KPI card grid layout, month-over-month panel type (sparkline or bar), issues table design, empty state when no data is loaded

**[DECIDE]** Empty states — designs for Accounts (no accounts added), Budget (no budget defined), and Overview (no data loaded)

---

### Development

~~**[DECIDE]** `OverviewEngine` stub contract~~ **Resolved R7** — `OverviewEngine` returns a typed "data not available" state (not nil, not empty zero values) when downstream engines are stubs; the Overview dashboard renders a distinct empty card. Documented in `docs/architecture/core-domain.md §3`.

---

## Phase 4 — Domain Layer II: Savings, Investments & Tax

### Product

**[FIX – S3]** Define requirements for the S&I "Overview" sub-nav item  
Tech Design §4 sidebar lists "Overview" as the first sub-item under Savings & Investments. Tech Design §16 S&I requirements are structured under "Goals must show:", "Assets must show:", and "Portfolio must show:" — there is no "Overview" section. Either add "Overview must show:" requirements to §16, or remove "Overview" from the sidebar and land users on Goals by default.

**[FIX – M8]** Reconcile Goals active/archived tabs between Phase 4 design task and Phase 5 dev task  
Roadmap Phase 4 design task specifies "active vs archived tabs" for the Goals overview. Roadmap Phase 5 `GoalsListView` dev task omits them. Add the active/archived tab to the Phase 5 task to match Phase 4.

**[DECIDE]** Savings goal progress derivation — when no `SavingsProgress` snapshot exists, how is current balance derived?
- Sum all transactions tagged `savings_goal_id` (requires consistent tagging)
- Use the linked account's current balance (works only if account is goal-dedicated)
- Require the user to enter a manual snapshot before goal shows a balance
- Which is the default, and can the user override per goal?

**[DECIDE]** Portfolio drift threshold — at what percentage difference between actual and target sleeve weight does the UI show a drift alert? Global setting in `settings.csv`, per-sleeve value in `sleeve-targets.csv`, or a hardcoded default?

**[DECIDE]** Benchmark period formulas:
- Periods ≤ 1Y: simple return `(end − start) / start × 100`?
- Periods 3Y and 5Y: CAGR `((end/start)^(1/years) − 1) × 100`?
- When a period start date falls on a weekend or holiday: use next trading day, or prior trading day?

**[DECIDE]** Sector performance data source — where does ticker-to-sector classification come from? Options: hardcoded map in the app, a user-maintained `Investments/sectors.csv`, or a `sector` column already on `holdings.csv`. What happens when a ticker has no sector classification — omit from chart, or group as "Other"?

**[DECIDE]** S&P 500 benchmark import format — is the ticker value in `benchmarks/sp500.csv` always `SPX`, `^GSPC`, or configurable? When price gaps exist (weekends, holidays), does the app interpolate, carry the prior close forward, or skip those dates in calculations?

**[DECIDE]** Standard deduction seeding — hardcode amounts per filing status per tax year, or read from a user-editable setting? Hardcoding is simpler; editable config is needed if the user wants to update before an app release ships.

**[DECIDE]** Schedule C / QBI estimate — flat-rate estimate (20% of qualified business income), or show a "requires manual entry" placeholder and let the user enter the figure?

**[DECIDE]** Tax prep checklist items — what are all checklist items and what data must exist for each to show as "complete"? Candidates:
- W-2 income: at least one `employment` account has YTD transactions for the tax year?
- 1099-INT / 1099-DIV: dividend records exist for investment accounts?
- Estimated payments: all four quarterly records exist and are marked paid?
- Deductions: all deduction rows have `status: confirmed`?

**[DECIDE]** Tax year-close archive scope and indicator — when "Close Tax Year" is triggered, exactly which files are archived? Just `deductions.csv` and `estimated-payments.csv`, or also a settings snapshot? What does the "year is closed" indicator look like — a lock icon, a read-only banner, or both?

---

### Design

**[DECIDE]** Goals overview — card anatomy (name, target, balance, progress bar, monthly contribution, time-to-goal estimate), active vs archived tab treatment

**[DECIDE]** Assets view — holdings table column set, allocation donut chart design, account selector

**[DECIDE]** Benchmark heat map — layout for 8 periods × N accounts, color scale for positive/negative growth, S&P 500 comparison row, sector performance section

**[DECIDE]** Sleeve detail — target vs actual weights table, drift indicator design, contribution target display

**[DECIDE]** Empty states — no goals created, no holdings imported, no price data available

**[DECIDE]** Tax overview — YTD taxable income panel, taxes paid vs owed comparison, effective rate per account table layout

**[DECIDE]** Deductions view — standard vs itemized comparison design, section structure (above-the-line, Schedule A, Schedule C)

**[DECIDE]** Estimated payments — quarterly schedule table, paid/due status per quarter

**[DECIDE]** Tax prep checklist — item anatomy, complete/incomplete/missing state designs, source link treatment

**[DECIDE]** Tax archive — prior-year selector, read-only mode indicators

---

### Development

**[DECIDE]** Savings goal balance source — if progress is derived from transactions, does `SavingsGoalEngine` sum from all files or only from the goal's linked account? If both a linked account and tagged transactions exist, which takes precedence?

**[DECIDE]** Tax lot tracking — auto-derived from `Trade` records (FIFO or specific lot) or managed as explicit rows in `tax-lots.csv`? The file spec exists but the derivation approach significantly affects `PortfolioEngine` and `TaxEngine` complexity.

---

## Phase 5 — Presentation Layer

### Product

**[DECIDE]** Filter states per section — for each module, which filters appear, what is the default state, and are filter states persisted across sessions or reset on navigation?
- Accounts: filter by account group (default all)? Active/inactive toggle?
- Budget: period selector (default current month)? Persisted?
- Savings & Investments: account selector (default all)? Goals active/archived tab persisted?
- Taxes: tax year selector (default current year)? Persisted?

**[DECIDE]** Traceability interaction — when the user taps a KPI card, does it navigate to the module main view or open a filtered drill-down? When the user taps a transaction row, does the right pane open automatically or only on an explicit "Inspect" action?

**[DECIDE]** Right pane open trigger — what action opens the right pane? Single click on a row, double-click, a dedicated Inspect button, or a keyboard shortcut? Does selecting a row always open it, or only when the pane is already open from a prior interaction?

**[DECIDE]** macOS menu bar commands and shortcuts — the full command list needs keyboard shortcuts assigned (no conflicts with system shortcuts) and commands placed in the correct menus (File, Edit, View, Workspace, Window).

---

### Design

**[FIX – C4]** Update `SavingsInvestmentsView` task to remove "Categories" sub-navigation  
Roadmap Phase 5 dev task reads: `SavingsInvestmentsView — "top-level view with Overview, Goals, Assets, and Categories sub-navigation"`. "Categories" was explicitly removed from S&I in the Round 3 update — deferred with the note "category and tag systems for Budget and S&I to be considered together." Update to: `Overview, Goals, Assets, Portfolio`.

**[DECIDE]** `NavigationSplitView` three-column layout spec — sidebar fixed width, minimum window size, column collapse behavior on narrow windows

**[DECIDE]** Left sidebar — section header styling, expand/collapse animation, nested entity link appearance, active/selected state, empty group state

**[DECIDE]** Context header — title and breadcrumb layout, quick action button set (Import, Add, Export), sync status badge, issue count badge

**[DECIDE]** Right detail pane — slide-over width, close button placement, all supported surface layouts (inspector, source file preview, repair preview, edit form)

**[DECIDE]** Shared component library — data table, KPI card, pie chart, sparkline, bar chart, heat map table, period selector, filter bar, empty state template, loading skeleton

**[DECIDE]** All five module wireframes — Overview (updated post Round 1), Accounts (new), Budget (updated with pie chart + trailing averages), Savings & Investments (unified), Taxes (updated with deductions view, per-account rates, archive)

---

### Development

**[DECIDE]** Deep link / state restoration format — `AppRouter` must encode navigation state for `NSUserActivity`. What is the format — a custom URL scheme (`openfinance://`) or a `UserActivity` user info dictionary? What is the schema for encoding domain + entity + filter state?

---

## Phase 6 — Write Flows, Repair & Export

### Product

**[DECIDE]** V1 write scope — confirm which entities are import-only in v1 (no in-app add/edit form). Candidates: transactions, holdings, trades, prices, dividends, tax lots. Are dividends import-only or can the user add them manually?

**[DECIDE]** Write preview requirements per entity — for each writable entity, what must the preview panel show before the user confirms? Minimum: affected file path, before/after row diff, backup location. Are there entity-specific additions (e.g. budget plan changes show pie chart impact)?

**[DECIDE]** Backup retention policy — how many timestamped backups are kept per source file before auto-pruning? Last N files (e.g. 10), files younger than N days (e.g. 30 days), or a combination? Is this configurable in settings or hardcoded?

**[DECIDE]** Export column inclusion — for CSV exports, are source provenance columns (`source_file`, `source_row`) included or stripped? Are derived/calculated columns included or only raw data? For Markdown summary exports, which sections are required (header, category breakdown, period totals)?

---

### Design

**[DECIDE]** Add Account form — account type picker grouped by account group, required field layout, submit/cancel

**[DECIDE]** Import CSV flow — file picker, column-mapping table design, validation summary, confirm/cancel

**[DECIDE]** Add/Edit transaction form — field layout, category picker behavior, account selector

**[DECIDE]** Add/Edit savings goal form — field layout, linked account picker, status selector

**[DECIDE]** Add/Edit deduction form — deduction type picker, entity link, status selector

**[DECIDE]** Write preview panel — before/after diff layout, backup location display, apply confirmation

**[DECIDE]** Repair preview panel — issue and fix description, diff view, backup confirmation, apply/cancel

**[DECIDE]** Export confirmation dialog — format picker (CSV / Markdown), file name, destination

---

### Development

**[DECIDE]** Import column mapper — auto-match source columns to canonical columns by name similarity, or always start blank for the user to map manually?

**[DECIDE]** Atomic write temp file location — temp files must be on the same volume as the target for atomic rename. Write to the same directory as the target (simpler but puts temp files in the iCloud-watched folder), or to a designated area inside `.finance-meta/`?

---

## Phase 7 — Polish & Launch Readiness

### Product

**[DECIDE]** Performance acceptance criteria — maximum acceptable times for:
- Cold launch to first projection displayed
- Full re-index of a realistic workspace (12 months of transactions, 3 investment accounts, 2 business entities)
- UI responsiveness during background re-index
- Time to apply a repair and re-validate

---

### Design

**[DECIDE]** Accessibility audit — VoiceOver labels for all interactive elements, keyboard focus order, WCAG AA color contrast across all views

**[DECIDE]** Dark mode audit — custom colors, chart palettes, status indicators across all views

**[DECIDE]** Responsive layout audit — minimum and comfortable window sizes, sidebar collapse behavior

**[DECIDE]** Final iconography — section icons, status icons, issue severity icons, account group icons

**[DECIDE]** Onboarding polish — first-launch empty state design, workspace creation success confirmation, "add your first account" prompt

---

## Item counts by phase

> Resolved items (~~strikethrough~~) are kept for history but excluded from open counts.

| Phase | FIX open | FIX resolved | DECIDE open | DECIDE resolved | Total open |
|---|---|---|---|---|---|
| Phase 1 — Foundation | 7 | 5 | 15 | 0 | 22 |
| Phase 2 — Parsing | 7 | 0 | 5 | 0 | 12 |
| Phase 3 — Domain I | 1 | 0 | 10 | 1 | 11 |
| Phase 4 — Domain II | 2 | 0 | 14 | 0 | 16 |
| Phase 5 — Presentation | 1 | 0 | 9 | 0 | 10 |
| Phase 6 — Write Flows | 0 | 0 | 7 | 1 | 7 |
| Phase 7 — Polish | 0 | 0 | 5 | 0 | 5 |
| **Total** | **18** | **5** | **65** | **2** | **83** |

---

*Last updated: 2026-06-24*
