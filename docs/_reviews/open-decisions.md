# Open Finance — Open Decisions

**Generated**: 2026-06-10  
**Source**: `docs/roadmap-v1.md` + `docs/technical design.md`  
**Scope**: All unresolved questions requiring a decision before or during each build phase, organized by phase then role. Locked decisions are recorded in `docs/technical design.md §21` and are not repeated here.

---

## Phase 1 — Foundation & Architecture

### Product

- **iCloud entitlement strategy**: What provisioning profile and signing approach is used for development vs distribution? Is a separate development container needed, or is one container identifier (`OpenFinance`) used across both environments?

- **7 iCloud sync states — UI surface**: For each state, what is the UI treatment? The seven states are: Available, Not signed into iCloud, Container unavailable, Syncing, Local copy stale, File missing locally, Conflict detected. Options per state: persistent toolbar badge, full-screen blocking prompt, dismissible banner, per-file row indicator, or no indicator.

- **`manifest.json` shape**: What fields are stored per-file entry? Minimum candidate: path, domain classification, `schema_version`, SHA-256 hash, last-indexed timestamp, last validation result summary. Are per-file sync state or repair history included here, or tracked separately?

### Design

- First-launch onboarding flow: workspace creation screens, iCloud availability states, and fallback UI when iCloud is unavailable
- Workspace sync status indicators: persistent status bar element design, per-file sync badge design for all 7 sync states
- Loading/indexing state: what the user sees between launch and when projections are ready (skeleton screens, progress indicator, or blocking state)
- Global app shell skeleton: window chrome, toolbar layout, menu bar structure, empty navigation state

### Development

- **`FileWatcherService` implementation choice**: `DispatchSource` (file descriptor watching, lower-level) vs `NSFilePresenter` (higher-level, integrates with iCloud file coordination) — which is used for watching the workspace directory?

- **`InvestmentAccount` model**: Investment accounts are now unified in `Accounts/accounts.csv`. Should the domain model use a single `Account` struct with optional investment fields, or two types (`Account` and a subtype `InvestmentAccount`) where `PortfolioEngine` works with the subtype?

---

## Phase 2 — Parsing, Validation & Infrastructure

### Product

- **CSV spec gaps**: The 24 file specs in `§8` need the following completed before `CSVSchemaRegistry` can be built:
  - Enum value sets for `account_group`, `account_type`, `trade_type`, `frequency`, `deduction_type`, `status`
  - Which columns in each spec are required vs optional at parse time
  - Whether `schema_version` is a CSV header comment row or a standard column — pick one format, apply consistently

- **Validation rule catalog**: All rules across three tiers (file-level, cross-file, domain) need: a rule ID, severity (error / warning / info), and repair classification (auto / manual / none). This catalog does not yet exist in any document and must be written before `RuleCatalog` can be implemented.

- **Validation issue classification examples requiring decisions**:
  - Is a missing optional column an error or a warning?
  - Is an unknown `category_id` reference on a transaction row an error or a warning?
  - Is an unknown `account_id` reference auto-repairable (prompt to add account) or manual-only?
  - Is a missing required folder auto-repairable (create it) or an error that blocks parsing?

### Design

- Validation issue card: icon and color system by severity, card layout (file path, issue text, remediation hint, repair vs manual badge)
- Repair preview panel: diff-style before/after row view, backup confirmation step, apply/cancel controls
- Indexing progress state: file count display, hash progress indicator, classification warnings surfaced during scan

### Development

- **`schema_version` header format**: Is `schema_version` stored as a comment in the CSV (e.g. `# schema_version: 1`), as a dedicated first column on every data row, or only tracked in the manifest? `CSVParserService` and `CSVSchemaRegistry` must agree on this.

- **Import sign-flip detection**: During import normalization, how does `CSVNormalizer` detect that a source file uses the opposite sign convention? Options: explicit user confirmation in the column-mapping step, a heuristic (if most amounts on expense categories are positive, flip), or always ask the user to declare source sign convention.

---

## Phase 3 — Domain Layer I: Accounts, Budget & Overview

### Product

- **Account type taxonomy**: The `account_group` enum has 7 groups. What are all valid `account_type` sub-types within each? For example:
  - `checking`: personal, joint
  - `savings`: HYSA, standard, money market
  - `investment`: taxable brokerage, Roth IRA, Traditional IRA, HSA, 401k, SEP-IRA
  - `credit_card`: personal, business
  - `loan`: mortgage, auto, personal, student
  - `employment`: W-2 payroll, 1099 contract
  - `business`: sole proprietor, LLC, S-Corp

- **Default budget category set**: What are the group names, category names, `default_budget_behavior` (fixed / discretionary / savings / investment / transfer), and `tax_relevant` flag for each? This is the seed data written by `bootstrap-workspace` and shown to every new user.

- **Entities/themes taxonomy**: The four built-in entity types are personal, employment, business, custom. What are their display labels, icon identifiers, and which account groups are valid under each? Can a user have more than one `employment` entity (e.g. two jobs)?

- **3-month trailing average — sparse data**: When fewer than 3 full months of transaction history exist, what does the trailing average column show? Options: partial average with a data-sufficiency label (e.g. "avg of 1 mo"), dashes until 3 months exist, or the available data with no special treatment.

- **Overview KPI card field specs**: Each of the 5 cards needs its exact field definitions:
  - **Budget**: What is "estimated spending" — sum of all budget plan rows, or actual-to-date with a projection for remaining days?
  - **Savings**: "Estimated rate" — account yield from account rules, or YTD growth rate from balance snapshots?
  - **Investments**: "Estimated rate" — YTD portfolio return, annualized benchmark return, or yield from account rules?
  - **Business**: Which entities are included — all `entity_type: business`, or only active ones?
  - **Taxes**: "Estimated return" — derived from `DeductionEngine` (taxes_paid − estimated_owed), or user-entered?

- **Month-over-month panel**: How many prior months are shown (3, 6, or 12)? When a month has no data, show a zero bar, a gap, or skip the month entirely?

- **YTD net income formula — per account group**: `gross_income − total_expenses − taxes_paid` — define each term per group:
  - `employment`: gross = all positive transactions; what counts as expenses? What counts as taxes paid?
  - `business`: gross = revenue; expenses = business expense transactions; taxes = estimated payments for the entity?
  - `checking`: gross = deposits; expenses = debits excluding transfers?
  - How are inter-account transfers excluded from both sides?

### Design

- **Accounts overview**: card grid layout, card anatomy (institution name, account type badge, monthly cash inflow, YTD net income), aggregate header row
- **Per-account detail**: chart type for monthly gross vs expenses/tax, YTD figures layout, transaction list within account context, account rules panel
- **Budget overview**: pie chart breakdown (fixed / discretionary / savings / investments as % of net income), category table column set (plan / actual / variance / 3-month average), period selector
- **Budget history**: view type (table vs bar chart), period range selector
- **Overview dashboard**: 5 KPI card grid layout, month-over-month panel type (sparkline or bar), Issues table, empty state
- Empty states for Accounts, Budget, and Overview (no accounts added, no transactions imported, no budget defined)

### Development

- **`OverviewEngine` stub contract**: When `PortfolioEngine` and `TaxEngine` are stubs in Phase 3, what does `OverviewEngine` return for the Investments and Taxes KPI cards — nil, empty placeholder values, or a typed "data not available" state that the UI renders as a distinct empty card?

---

## Phase 4 — Domain Layer II: Savings, Investments & Tax

### Product

#### Savings & Investments

- **Savings goal progress derivation**: When no `SavingsProgress` snapshot exists, how is the current balance derived?
  - Sum all transactions tagged with `savings_goal_id` (requires tagging discipline)
  - Use the linked account's current balance (works only if the account is goal-dedicated)
  - Require the user to enter a manual snapshot before the goal shows a balance
  - Which is the default, and can the user override per goal?

- **Portfolio drift threshold**: At what percentage difference between actual and target sleeve weight does the UI show a drift alert? Global setting in `settings.csv`, per-sleeve value in `sleeve-targets.csv`, or a hardcoded default?

- **Benchmark period formulas**:
  - Periods ≤ 1Y: simple return `(end − start) / start × 100`?
  - Periods 3Y and 5Y: CAGR `((end/start)^(1/years) − 1) × 100`?
  - When a period start date falls on a weekend or holiday: use next trading day's price, or prior trading day's price?

- **Sector performance data source**: Where does ticker-to-sector classification come from? Options: hardcoded map in the app, a user-maintained `Investments/sectors.csv`, or a `sector` column on `holdings.csv`. What happens when a ticker has no sector classification — omit from chart, or group as "Other"?

- **S&P 500 benchmark import format**: What is the expected column format for `benchmarks/sp500.csv`? The spec has `ticker`, `date`, `close` — is the ticker value always `SPX`, `^GSPC`, or configurable? When price gaps exist (weekends, holidays), does the app interpolate, carry the prior close forward, or skip those dates in calculations?

#### Taxes

- **Standard deduction seeding**: Should standard deduction amounts be hardcoded in the app per filing status per tax year, or read from a user-editable value in settings? Hardcoding is simpler and reduces user error; editable is needed if the user wants to update before an app release ships.

- **Schedule C / QBI estimate**: For the QBI deduction shown in the Tax module: use a simplified flat-rate estimate (20% of qualified business income), or show a "requires manual entry" placeholder and let the user enter the figure?

- **Tax prep checklist items**: What are all checklist items and what data must exist for each to show as "complete"? Candidates:
  - W-2 income: complete when at least one `employment` account has YTD transactions for the tax year?
  - 1099-INT / 1099-DIV: complete when dividend records exist for investment accounts?
  - Estimated payments: complete when all four quarterly records exist and are marked paid?
  - Deductions: complete when all deduction rows have `status: confirmed`?

- **Tax year-close — archive scope and indicator**: When the user triggers "Close Tax Year", exactly which files are archived — `deductions.csv` and `estimated-payments.csv` only, or also a settings snapshot? What does the "year is closed" indicator look like — a lock icon on the archive entry, a read-only banner in the Tax overview, or both?

### Design

#### Savings & Investments

- **Goals overview**: goal card anatomy (name, target amount, current balance, progress bar, monthly contribution, time-to-goal estimate), active vs archived tab treatment
- **Assets view**: holdings table column set, allocation donut chart design, account selector
- **Benchmark heat map**: table layout for 8 periods × N accounts, color scale for positive/negative growth, S&P 500 comparison row, sector performance section
- **Sleeve detail**: target vs actual weights table, drift indicator design, contribution target display
- Empty states: no goals created, no holdings imported, no price data available

#### Taxes

- **Tax overview**: YTD taxable income panel, taxes paid vs owed comparison, effective rate per account table layout
- **Deductions view**: standard vs itemized comparison design, section structure (above-the-line, Schedule A, Schedule C)
- **Estimated payments**: quarterly schedule table, paid/due status per quarter
- **Tax prep checklist**: item anatomy, complete/incomplete/missing state designs, source link treatment
- **Tax archive**: prior-year selector, read-only mode indicators

### Development

- **Savings goal balance source**: If progress is derived from transactions, does `SavingsGoalEngine` sum transactions tagged `savings_goal_id` from all files, or only from the goal's linked account? If both a linked account and tagged transactions exist, which takes precedence?

- **Tax lot tracking**: Are tax lots derived automatically from `Trade` records (FIFO or specific lot), or managed as explicit rows in `tax-lots.csv`? The file spec exists but the derivation approach affects `PortfolioEngine` and `TaxEngine` complexity significantly.

---

## Phase 5 — Presentation Layer

### Product

- **Filter states per section**: For each module, which filters appear, what is the default state, and are filter states persisted across sessions or reset on navigation?
  - Accounts: filter by account group (default all)? Active/inactive toggle?
  - Budget: period selector (default current month)? Persisted across sessions?
  - Savings & Investments: account selector (default all)? Goals active/archived tab persisted?
  - Taxes: tax year selector (default current year)? Persisted?

- **Traceability interaction**: When the user taps a KPI card, does it navigate to the module's main view or open a filtered drill-down? When the user taps a transaction row, does the right pane open automatically or only on an explicit "Inspect" action?

- **Right pane open trigger**: What action opens the right pane?
  - Single click on a row
  - Double-click only
  - A dedicated Inspect button or keyboard shortcut
  - Does selecting a row always open it, or only when the pane is already open from a prior interaction?

- **macOS menu bar commands and shortcuts**: The full command list needs keyboard shortcuts assigned (no conflicts with system shortcuts) and commands placed in the correct menus. Which commands appear in File, Edit, View, Workspace, and Window menus?

### Design

- `NavigationSplitView` three-column layout spec: sidebar fixed width, minimum window size, column collapse behavior on narrow windows
- Left sidebar: section header styling, expand/collapse animation, nested entity link appearance, active/selected state, empty group state
- Context header: title and breadcrumb layout, quick action button set (Import, Add, Export), sync status badge, issue count badge
- Right detail pane: slide-over width, close button placement, all supported surface layouts (inspector, source file preview, repair preview, edit form)
- Shared component library: data table, KPI card, pie chart, sparkline, bar chart, heat map table, period selector, filter bar, empty state template, loading skeleton
- All five module wireframes: Overview (updated), Accounts (new), Budget (updated), Savings & Investments (unified), Taxes (updated)

### Development

- **Deep link / state restoration format**: `AppRouter` must encode navigation state for `NSUserActivity`. What is the format — a custom URL scheme (`openfinance://`) or a `UserActivity` user info dictionary? What is the schema for encoding domain + entity + filter state?

---

## Phase 6 — Write Flows, Repair & Export

### Product

- **V1 write scope — import-only list**: Confirm which entities are import-only in v1 (no in-app add/edit form). Candidates: transactions, holdings, trades, prices, dividends, tax lots. Are dividends import-only or can the user add them manually? Are tax lots import-only or derived?

- **Write preview requirements per entity**: For each writable entity, what must the preview panel show before the user confirms? At minimum: affected file path, before/after row diff, backup location. Are there entity-specific additions (e.g. budget plan changes show pie chart impact)?

- **Backup retention policy**: How many timestamped backups are kept per source file before auto-pruning — last N files (e.g. 10), files younger than N days (e.g. 30), or a combination? Is this configurable in settings or hardcoded?

- **Export column inclusion**: For CSV exports, are source provenance columns (`source_file`, `source_row`) included or stripped? Are derived/calculated columns included or only raw data columns? For Markdown summary exports, what sections are required (header, category breakdown, period totals)?

### Design

- Add Account form: account type picker grouped by account group, required field layout, submit/cancel
- Import CSV flow: file picker, column-mapping table, validation summary, confirm/cancel
- Add/Edit transaction form: field layout, category picker, account selector
- Add/Edit savings goal form: field layout, linked account picker, status selector
- Add/Edit deduction form: deduction type picker, entity link, status selector
- Write preview panel: before/after diff layout, backup location, apply confirmation
- Repair preview panel: issue and fix description, diff, backup confirmation, apply/cancel
- Export confirmation dialog: format picker (CSV / Markdown), file name, destination

### Development

- **Import column mapper — auto-match**: Does the import column mapper attempt to auto-match source columns to canonical columns by name similarity, or always start blank for the user to map manually?

- **Atomic write temp file location**: Temp files must be on the same volume as the target file for atomic rename to work. Does the app write temp files to the same directory as the target (simpler but puts temp files in the iCloud-watched folder), or use a designated temp area inside `.finance-meta/`?

---

## Phase 7 — Polish & Launch Readiness

### Product

- **Performance acceptance criteria**: What are the maximum acceptable times for:
  - Cold launch to first projection displayed
  - Full re-index of a realistic workspace (12 months of transactions, 3 investment accounts, 2 business entities)
  - UI responsiveness during background re-index
  - Time to apply a repair and re-validate

### Design

- Accessibility audit: VoiceOver labels for all interactive elements, keyboard focus order, WCAG AA color contrast
- Dark mode audit: custom colors, chart palettes, status indicators across all views
- Responsive layout audit: minimum and comfortable window sizes, sidebar collapse behavior
- Final iconography pass: section icons, status icons, issue severity icons, account group icons
- Onboarding polish: first-launch empty state design, workspace creation success confirmation, "add your first account" prompt

---

*Last updated: 2026-06-10*
