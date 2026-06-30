# Pre-Build Items

**Generated**: 2026-06-10  
**Last updated**: 2026-06-30 (Phase 3 build complete on branch `004-domain-accounts-budget-overview`, pending CI + merge)  
**Sources**: `docs/_notes/consistency-audit.md` · `docs/_notes/open-decisions.md`  
**Purpose**: Single consolidated reference of every outstanding item before and during each build phase. Replaces both source documents for day-to-day use.

> **Build status (2026-06-30):** **Phases 1 and 2 are complete and merged to `main`** (specs
> `002-foundation-architecture`, PR #15; `003-parsing-validation`, PR #16). The app is a **Swift
> Package** (`Sources/FinanceWorkspaceKit/{Platform,Parsing,Validation,Domain,Persistence,Migration}/`
> + the `FinanceWorkspaceApp`/`bootstrap-workspace`/`fixture-generate`/`index-check`/`validate-workspace`/`repair-workspace`/`migrate-r6`
> executables), not a hand-authored `.xcodeproj`. macOS build/test CI (`ci-macos.yml`) landed in
> Phase 1.
>
> **Phase 2 delivered** the Parsing layer, `ValidationEngine` + full `RuleCatalog` (34 rules),
> `RepairService`, `SettingsStore`, `MigrationService`, and 23 bundled JSON schemas — confirmed by
> the Milestone 2 gate (T043). This retires the two partially-resolved Phase 2 `[DECIDE]`s (CSV
> spec gaps, validation rule catalog) and all five `R6-M1…M5` `[FIX]`s below.
>
> **Still deferred:** the iCloud ubiquity-container **entitlement** + dev code signing (needs the
> Xcode app target, added in Phase 5). The implemented domain models settle several Phase 1
> doc-naming FIX items in code — `UnifiedTransaction` (M6), `AccountGroup` (C6/S9), single `Account`
> + optional `InvestmentMetadata` (C1) — though the architecture-doc text for M1/M3/M4 may still
> warrant a consistency pass in a future round. **Phase 3 (Domain Layer I) is build-complete on branch
`004-domain-accounts-budget-overview`** (39/39 tasks; Milestone 3 reached) — pending CI + merge. It
retires `[FIX-C2]` and all seven Phase-3 product `[DECIDE]`s (taxonomy, category seed, employment
groups, trailing-average sparse handling, KPI card specs, MoM panel, YTD net income); the six Phase-3
**Design** `[DECIDE]`s remain Phase-5 work. **Phase 4 (Domain Layer II) is next, not started.**

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

~~**[FIX – S9]** Add display name → enum value mapping for account groups~~ **Resolved R8** — Mapping encoded in the accounts JSON schema and documented in `docs/architecture/containers-and-budgets.md §3.21`: "Everyday Banking" → `checking`, "Credit Cards" → `credit_card`, "Loans & Debt" → `loan`, etc.

~~**[FIX – S5]** Decide whether `OwnerDistribution` is in scope for v1~~ **Resolved R8** — Removed from v1. Cut from PRD data model and the Roadmap Phase 1 entity list. Owner-draw accounting deferred to V2.

~~**[FIX – M5]** Align AI integration language~~ **Resolved R7** — PRD §3 non-goals already reads "AI integrations … V2 deferred" (R7 changelog). Verified during R8.

~~**[DECIDE]** iCloud entitlement strategy~~ **Resolved R8** — Single `iCloud.<bundle-id>` container across development and distribution (iCloud Documents has no dev/prod split; the bare `OpenFinance` value was malformed and is corrected). Dev-data isolation is at the provider layer via the DEBUG local-folder provider (`~/Finance-Dev/`), not a separate container. See `docs/technical-design.md §5/§21`.

~~**[DECIDE]** 7 iCloud sync states~~ **Resolved R8** — UI-treatment table in `docs/technical-design.md §5` (no-indicator / blocking / banner / per-file as appropriate); per-file state sourced from `NSMetadataQuery`; conflicts resolved manually via `NSFileVersion` (no auto-merge). Writes gate on sync state per the locked sync-first write gate.

~~**[DECIDE]** `manifest.json` per-file field set~~ **Resolved R8** — Device-local regenerable cache at `~/Library/Application Support/OpenFinance/<workspace_id>/manifest.json` (out of the synced container). Fields: `path, domain, subtype, schema_version, hash, modified_at, byte_size, row_count, last_indexed_at, validation_status`; top level `manifest_schema_version, app_version, workspace_id, last_indexed_at`. Sync state and repair history excluded. See `docs/technical-design.md §9`.

---

### Design

~~**[DECIDE]** Figma → code handoff policy~~ **Resolved R7** — figma-cli (local CLI via CDP, no API key). Yolo mode default. Claude Code reads design specs live from Figma Desktop. Design tokens exported to `docs/_design/tokens/` (DTCG/W3C format); icons/SVG assets exported to `docs/_design/icons/`. Component specs generated on demand, not committed. Set up figma-cli in Phase 1 — Claude Code handles installation.

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

~~**[FIX – S6]** Add service descriptions for `FileCoordinatorService`, `ManifestStore`, and `SettingsStore`~~ **Resolved R8** — All three added to `docs/architecture/core-domain.md §3`. `ManifestStore` reads/writes the device-local Application Support manifest and rebuilds from scan if missing.

**[FIX – M1]** Align layer count across documents  
PRD describes 4 layers, CLAUDE.md 5 layers, Tech Design 6 layers. These are different decompositions of the same architecture. Add a note to Tech Design §3 that the PRD 4-layer model is a simplified view, or update all documents to use the same count.

~~**[FIX – M2]** Remove `ReportingEngine` from PRD core modules~~ **Resolved R7** — PRD §5 Technical Architecture no longer lists `ReportingEngine` (R7 changelog: removed, added Benchmark/TaxAdjustment/TaxPrep/Overview engines). Verified during R8.

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

~~**[DECIDE]** macOS deployment target~~ **Resolved R7** — macOS 15 (Sequoia). Update to the latest stable macOS at Phase 1 build start if newer. Documented in `CLAUDE.md` and `docs/architecture/core-domain.md §2`.

~~**[DECIDE]** Xcode and Swift version requirements~~ **Resolved R7** — Xcode 16, Swift 6. Update to latest stable at Phase 1 build start. Documented in `CLAUDE.md` and `docs/architecture/core-domain.md §2`.

~~**[DECIDE]** CI/CD pipeline~~ **Resolved R7** — GitHub Actions. Phase 1: SwiftLint on a standard Linux runner only (no Mac build CI). Full Mac build CI deferred to Phase 5. Code signing and entitlements are developer-machine only in Phase 1.

~~**[DECIDE]** `FileWatcherService` implementation~~ **Resolved R8** — `NSMetadataQuery` (iCloud provider; also yields per-file sync state) + FSEvents (local-folder provider). `DispatchSource` and hand-rolled `NSFilePresenter`-as-watcher rejected; `NSFileCoordinator`/`NSFilePresenter` are for read/write coordination only. See `docs/architecture/core-domain.md §3`.

~~**[DECIDE]** `Account` model shape~~ **Resolved R8** — Single struct with optional nested `InvestmentMetadata?`; no `InvestmentAccount` subtype. `PortfolioEngine` filters `account_group == .investment`. See `docs/technical-design.md §21` and `docs/architecture/core-domain.md §1`.

---

## Phase 2 — Parsing, Validation & Infrastructure

### Product

~~**[FIX – S4]** Decide the purpose of `savings-goal-contributions.csv` or remove it~~ **Resolved R8** — Removed. `savings_goal_id` on the unified transaction ledger is the sole budget-to-goal linking mechanism. Dropped from the folder structure in `docs/architecture/containers-and-budgets.md §1`.

~~**[FIX – S7]** Define the savings goal `status` enum values~~ **Resolved R8** — `status ∈ {active, archived}` (`completed` derived from progress ≥ target; `paused` not in v1). Reverses the earlier "lifecycle is V2" note. `goals.csv` spec updated; `SavingsGoalEngine` description updated.

~~**[DECIDE]** CSV spec gaps~~ **Resolved (Phase 2 build, 2026-06-30)** — The full set of canonical JSON schemas (23, one per managed file type) is authored and **bundled** with the library at `Sources/FinanceWorkspaceKit/Resources/Schemas/` (loaded via `Bundle.module`, mirrored into `.finance-meta/schemas/` at bootstrap). Each schema enumerates required-vs-optional columns and the enum value sets (`account_group`, `account_type`, `trade_type`, `frequency`, `adjustment_type`, `status`, …), enforced by `CSVSchemaRegistry`. `schema_version` is the leading `# schema_version: N` comment row (tolerant parser).

~~**[DECIDE]** Validation rule catalog~~ **Resolved (Phase 2 build, 2026-06-30)** — The full per-rule catalog is implemented in `RuleCatalog` / `Validation/Rules/`: **34 rules** in the locked `VAL-<TIER>-<NNN>` shape — 15 file-level (`VAL-FILE-001…015`), 11 cross-file (`VAL-CROSS-001…011`), 8 domain (`VAL-DOMAIN-001…008`), each carrying tier, severity, repair class, and message template. Run by `ValidationEngine`; confirmed by the Milestone 2 gate.

~~**[DECIDE]** Validation issue classification~~ **Resolved R8** — Defaults set in `docs/architecture/rulesets-and-taxes.md`: missing optional column → warning/auto; unknown `category_id` → warning/manual; unknown `account_id` on a transaction → error/manual (assisted create, no silent add); missing required folder → info/auto. Severity philosophy: errors block; warnings surface; info silent.

---

### Design

**[DECIDE]** Validation issue card — icon and color system by severity, card layout (file path, issue text, remediation hint, repair vs manual badge)

**[DECIDE]** Repair preview panel — diff-style before/after row view, backup confirmation step, apply/cancel controls

**[DECIDE]** Indexing progress state — file count display, hash progress indicator, classification warnings surfaced during scan

---

### Development

~~**[DECIDE]** `schema_version` header format~~ **Resolved R8** — Leading CSV comment row `# schema_version: N` (line 1); `CSVParserService` tolerates and strips leading `#` lines; absent → current registry version + flag for repair. (Accepted tradeoff: Numbers/Excel show it as a junk first row.)

~~**[DECIDE]** Import sign-flip detection~~ **Resolved R8** — Explicit per-import declaration in the column-mapping step, with a heuristic pre-fill the user confirms. Never silently flip. See `docs/architecture/data-pipelines.md §3.1`.

~~**[FIX – R6-M1]** Apply R6 schema renames in `CSVSchemaRegistry`~~ **Resolved (Phase 2 build, 2026-06-30)** — The bundled schemas use the R6 names: `account-groups.schema.json` (`account_group_id`), `assets.schema.json` (`asset_id`), `tax-adjustments.schema.json` (`tax_adjustment_id`); `CSVSchemaRegistry` registers them. Legacy names are handled by `migrate-r6` (R6-M5).

~~**[FIX – R6-M2]** Add `Accounts/liabilities.csv` spec to `CSVSchemaRegistry`~~ **Resolved (Phase 2 build, 2026-06-30)** — `liabilities.schema.json` is bundled and registered.

~~**[FIX – R6-M3]** Add `Investments/portfolios.csv` and sleeve files to `CSVSchemaRegistry`~~ **Resolved (Phase 2 build, 2026-06-30)** — `portfolios.schema.json`, `sleeves.schema.json`, and `sleeve-targets.schema.json` are all bundled and registered.

~~**[FIX – R6-M4]** Add `group_id` and `group_role` columns to the unified transaction schema~~ **Resolved (Phase 2 build, 2026-06-30)** — `transactions.schema.json` carries the multi-entry `group_id` / `group_role` columns; the multi-entry group rules are in the validation catalog (`VAL-DOMAIN-*`).

~~**[FIX – R6-M5]** Create one-time `migrate-r6.swift` migration script~~ **Resolved (Phase 2 build, 2026-06-30)** — `MigrationService` + the `migrate-r6` CLI (`Sources/migrate-r6/`) implement the preview-able, idempotent migration: rename the three legacy files/FK columns, fold `Investments/transactions.csv` into the unified ledger as `type = trade` rows, seed new R6 files, bump `schema_version`, update the manifest. Delivered as US5 (T035–T038).

~~**[FIX – R7-P1]** Update prototype `data.js` write/edit flows~~ **Resolved R7** — Prototype now demonstrates the full add/edit/delete cycle: add-transaction modal and manual single-entry flow, edit account/transaction/goal/category/group side panels, **delete with reference-check reassignment preview** (per-collection reassignment picker, atomic delete + reassign — matches the locked Round 7 reassign policy), and a two-step **import CSV column-mapping flow** (file picker → auto-detected column-mapping table → import). `prototype/data.js` also carries the full R6 schema (accountGroups, assets, taxAdjustments, liabilities, portfolios, multi-entry transactions with `groupId`/`groupRole`). Tracked per `docs/_refinement/r7-review.md` items A2/B1/B2.

---

## Phase 3 — Domain Layer I: Accounts, Budget & Overview

### Product

~~**[FIX – C2]** Correct the Phase 3 critical dependency note in the roadmap~~ **Resolved (Phase 3 build, `004-domain-accounts-budget-overview`)** — verified the roadmap Phase 3 "Critical dependency" note (`docs/product-roadmap.md`) already references the correct paths: master registry `Accounts/accounts.csv` plus `account_group_id` from `Accounts/account-groups.csv`; no `Investments/accounts.csv` or `Business/entities.csv` references remain. The stale-path text this item described was corrected in an earlier round; this closes the tracking entry.

~~**[DECIDE]** Account type taxonomy~~ **Resolved (Phase 3 build)** — canonical `account_type` per `account_group` shipped as `AccountTypeTaxonomy` (`checking` {personal, joint}; `savings` {hysa, standard, money_market}; `investment` {taxable, roth_ira, traditional_ira, hsa, 401k, sep_ira}; `credit_card` {personal, business}; `loan` {mortgage, auto, personal, student}; `employment` {w2, 1099}; `business` {sole_prop, llc, s_corp}). `account_type` stays a free-string schema column (forward-compatible); the seed accounts use canonical values.

~~**[DECIDE]** Default budget category set~~ **Resolved (Phase 3 build)** — 16-row seed across six groups (Income {salary, business_income — fixed/tax_relevant}, Essentials {housing, groceries, utilities, transport, insurance}, Lifestyle {dining, entertainment, shopping, travel — discretionary}, Savings {emergency, goals — savings}, Investments {retirement, brokerage — investment}, Transfers {transfer}) in `WorkspaceLayout`. `tax_relevant` on income + insurance.

~~**[DECIDE]** Entities/themes taxonomy~~ **Resolved (Phase 3 build, engine portion)** — **multiple `employment` account-groups are allowed** (each job is its own group; engines aggregate across them). The four `group_type`s (personal/employment/business/custom) are the canonical taxonomy. Display labels / icon identifiers are UI and stay with the Phase-5 design work.

~~**[DECIDE]** 3-month trailing average — sparse data~~ **Resolved (Phase 3 build)** — partial average with a data-sufficiency signal (`TrailingAverage{value, monthsAvailable, isPartial}`, label "avg of N mo"); never zero/blank for a category with ≥1 month; `monthsAvailable == 0` → `value == nil` (UI renders a dash).

~~**[DECIDE]** Overview KPI card field specs~~ **Resolved (Phase 3 build, Phase-3 scope)** — Budget card = current-month income vs estimated spending (fixed + discretionary); Savings card (AccountEngine) = savings-group balance + current-month inflow; Business card = business-group YTD net income (active accounts via `status`); Investments + Taxes cards return the typed "data not available" state (PortfolioEngine/TaxEngine = Phase 4). The "estimated rate" formulas for Savings/Investments are Phase-4 (`OOS-6`).

~~**[DECIDE]** Month-over-month panel~~ **Resolved (Phase 3 build)** — trailing **6** months; months with no data are **skipped** (not zero-barred).

~~**[DECIDE]** YTD net income formula~~ **Resolved (Phase 3 build)** — `gross − expenses − taxes_paid`, YTD anchored to the workspace `tax_year`, `type = transfer` excluded from both sides; `taxes_paid` = explicit tax line items (withholding legs + standalone tax-payment rows). Per-group: employment/checking gross = positive income rows; business gross = revenue rows. Plus the personal-inflow vs **retained-equity** split (business income retained in business accounts; investment/reinvested-gain retained equity → Phase 4, `OOS-4`).

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
| Phase 1 — Foundation | 5 | 11 | 4 | 9 | 9 |
| Phase 2 — Parsing | 0 | 8 | 3 | 5 | 3 |
| Phase 3 — Domain I | 0 | 1 | 6 | 8 | 6 |
| Phase 4 — Domain II | 2 | 0 | 21 | 0 | 23 |
| Phase 5 — Presentation | 1 | 0 | 11 | 0 | 12 |
| Phase 6 — Write Flows | 0 | 0 | 14 | 0 | 14 |
| Phase 7 — Polish | 0 | 0 | 6 | 0 | 6 |
| **Total** | **8** | **20** | **65** | **22** | **73** |

> **Phase 3 build complete on branch (2026-06-30)** retired 8 open Phase 3 items: `[FIX-C2]` and all
> seven Phase-3 product `[DECIDE]`s (account-type taxonomy, default category set, employment-group
> taxonomy, 3-month trailing-average sparse handling, Overview KPI card specs, MoM panel, YTD net
> income). The 6 remaining open Phase 3 items are **Design** `[DECIDE]`s (Accounts overview,
> per-account detail, Budget overview, Budget history, Overview dashboard, empty states) — UI design
> that lands with the Presentation layer (Phase 5), not part of the engine spec `004`.
>
> **Phase 2 build complete (2026-06-30)** retired 7 open Phase 2 items: the two partially-resolved `[DECIDE]`s (CSV spec gaps, validation rule catalog — now fully resolved by the 23 bundled JSON schemas + the 34-rule `RuleCatalog`) and all five `R6-M1…M5` `[FIX]`s. The 3 remaining open Phase 2 items are **Design** `[DECIDE]`s (validation issue card, repair preview panel, indexing progress state) — UI design that lands with the Presentation layer (Phase 5), not part of the engine spec `003`.
>
> **Round 8 (2026-06-26)** retired 15 open items (Phase 1: 5 FIX + 5 DECIDE; Phase 2: 2 FIX + 3 DECIDE).

---

*Last updated: 2026-06-30 (Phase 3 build complete on branch — pending CI + merge)*
