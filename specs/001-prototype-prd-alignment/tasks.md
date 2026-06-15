# Tasks: Prototype as Design Source of Truth

**Input**: Design documents from `specs/001-prototype-prd-alignment/`
**Prerequisites**: plan.md ✅ · spec.md ✅ · research.md ✅ · data-model.md ✅ · contracts/ ✅
**Tests**: SC-013 (jsdom smoke test) was run from `/tmp/protosmoke` during the Round 5 audit — 19/19 assertions passed. Committing `prototype/smoke.js` is a P4 Known Gap tracked in `spec.md`.
**Source files**: `prototype/app.js` · `styles.css` · `index.html` · `data.js` · `store.js` (added Round 5)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (independent of concurrent tasks in same phase)
- **[Story]**: Which user story this task belongs to

---

## Phase 1: Setup — Mock Data

**Purpose**: Extend `data.js` with all new mock data constants required by new view functions.
All 5 tasks are independent additions to `data.js`.

- [x] T001 Add `DATA.accounts` array to `prototype/data.js` — min 4 mock accounts, 3+ distinct groups (Everyday Banking, Investments, Credit Cards), each with `id`, `name`, `institution`, `group`, `type`, `monthlyInflow`, `ytdNetIncome`
- [x] T002 [P] Add `DATA.iCloudStates` array to `prototype/data.js` — 7 iCloud states plus `workspace-created` success state, each with `id`, `label`, `icon`, `description`, `recoveryAction`
- [x] T003 [P] Add `DATA.benchmarkReturns` array to `prototype/data.js` — one row per investment account plus `sp500`, each with `returns` object keyed by `D W M 3M 6M 1Y 3Y 5Y`; mix positive, negative, and null values
- [x] T004 [P] Add `DATA.deductions` array to `prototype/data.js` — at least 2 entries per type (`standard`, `above-line`, `schedule-a`, `schedule-c`), each with `id`, `type`, `name`, `estimatedAmount`, `status`
- [x] T005 [P] Add `DATA.accountTaxRates` array to `prototype/data.js` — one row per mock account, each with `accountId`, `accountName`, `taxableIncome`, `taxesPaid`, `taxesOwed`, `effectiveRate`

**Checkpoint**: `data.js` exports all 5 new arrays with plausible mock values. Open prototype in browser — no JS errors on load.

---

## Phase 2: Foundational — State, Shell, and Inspector Infrastructure

**Purpose**: Update state shape, HTML shell, CSS, and core inspector helpers. These changes are
prerequisites for every user story phase that follows.

**⚠️ CRITICAL**: All user story work is blocked until this phase is complete.

- [x] T006 Add `syncState: 'synced'` and `inspectorOpen: false` to the `state` object in `prototype/app.js` (line ~77, inside the `const state = {` block)
- [x] T007 [P] Add inspector slide-over CSS to `prototype/styles.css`: `#inspector` fixed-position right overlay with `transform: translateX(100%)` default and `transform: translateX(0)` when `.inspector-open` class is present; add `#inspector-backdrop` semi-transparent overlay behind it; add `transition: transform 0.22s ease` for smooth animation
- [x] T008 [P] Update `prototype/index.html`: move sync pill from sidebar footer into `#toolbar`; add `#inspector-backdrop` div inside `<body>` (before `<aside id="inspector">`); give the inspector aside a fixed width of 360px
- [x] T009 Add `openInspector(kind, id)` and `closeInspector()` helper functions to `prototype/app.js`: `openInspector` sets `state.selection`, sets `state.inspectorOpen = true`, adds `.inspector-open` class to `#inspector`, shows backdrop; `closeInspector` clears both, removes class, hides backdrop
- [x] T010 Update the `navigate()` function in `prototype/app.js` to call `closeInspector()` before rendering — ensures inspector always closes on any navigation change (FR-005)

**Checkpoint**: Open prototype. Right panel is absent on load. Calling `openInspector('test','1')` in the console makes a panel slide in from the right without shifting `<main>`. Calling `closeInspector()` slides it back out.

---

## Phase 3: User Story 1 — App Shell and Navigation Structure (Priority: P1) 🎯 MVP

**Goal**: Correct v1 sidebar, toolbar, and default load state. Every subsequent story review depends on the navigation being right first.

**Independent Test**: Open prototype. Read sidebar top-to-bottom: Overview, Accounts, Budget, Savings & Investments, Business, Taxes, Settings — nothing else. Expand Budget: no Rules sub-item. Expand Overview: only Dashboard. Initial load shows Accounts screen. Right panel absent.

- [x] T011 [US1] Rewrite the `NAV` constant in `prototype/app.js` to match the canonical array in `specs/001-prototype-prd-alignment/contracts/nav-structure.md`: 7 top-level groups, correct sub-items, no Monthly Snapshots / Annual Snapshots / Rules / Notes / Issues / Files entries
- [x] T012 [US1] Update initial `state.view` value in `prototype/app.js` from `'overview-dashboard'` to `'accounts-overview'` (FR per US1 acceptance scenario 5)
- [x] T013 [US1] Update `renderCenter()` dispatch table in `prototype/app.js` to add cases for all new view IDs from the NAV contract: `accounts-overview`, `budget-overview`, `savings-goals`, `savings-goals-active`, `savings-goals-archived`, `taxes-deductions`, `onboarding`; stub unimplemented views with a placeholder `el('p', {text: 'Coming in this sprint'})` return so navigation never crashes
- [x] T014 [US1] Update the `filters` map in `prototype/app.js` `state` object: rename `personal-budget-current` key to `budget-overview`; add empty filter objects for `accounts-overview`, `savings-investments`, `taxes-deductions`

**Checkpoint**: Sidebar matches spec exactly. Click every nav item — no JS errors. Default load shows Accounts placeholder. Notes, Issues, Files, Rules not reachable.

---

## Phase 4: User Story 2 — Right Detail Panel as Slide-Over (Priority: P2)

**Goal**: Inspector is a slide-over overlay. Main content never shifts. Panel closes on navigation and outside-click.

**Independent Test**: Navigate to any module with a table. Confirm no panel on load. Click a row — panel slides in from right, main content width unchanged. Click outside — panel closes. Navigate away — panel stays closed.

- [x] T015 [US2] Update `renderInspector()` in `prototype/app.js` to be a no-op when `state.inspectorOpen === false` (return early); when true, populate the `#inspector` aside with selection-appropriate content using the existing inspector render logic
- [x] T016 [US2] Update all table row `onclick` handlers in `prototype/app.js` to call `openInspector(kind, id)` instead of setting `state.selection` directly and calling `renderInspector()` (search for `state.selection =` and `renderInspector()` call pairs — replace each with `openInspector()`)
- [x] T017 [US2] Wire the `#inspector-backdrop` click handler in `prototype/app.js` (add an `onclick` attribute or event listener in the initialization block at the bottom) to call `closeInspector()`

**Checkpoint**: Open prototype. No panel on load. Click a transaction row — panel slides in without content shift. Click backdrop — panel closes. Navigate to different section — panel is absent.

---

## Phase 5: User Story 3 — First-Launch Onboarding Flow (Priority: P3)

**Goal**: All 7 iCloud states plus workspace-created success state are visually designed and reachable via Settings → Workspace.

**Independent Test**: Settings → Workspace → "Show onboarding" navigates to onboarding view. Count state cards: expect 8 (7 iCloud states + success). Each card has a title, icon, description, and recovery action where applicable.

- [x] T018 [US3] Add `viewOnboarding()` function to `prototype/app.js`: renders a full-width card grid from `DATA.iCloudStates`; each card shows `icon`, `label`, `description`, and (if `recoveryAction !== null`) a CTA button; add a "workspace-created" success card at the end showing workspace path, workspace ID, and a "Start using app" action
- [x] T019 [US3] Update `viewSettingsWorkspace()` in `prototype/app.js` to include a "Show onboarding flow" button that calls `navigate('onboarding')`
- [x] T020 [US3] Add CSS for onboarding card grid to `prototype/styles.css`: `.onboarding-grid` with 2-column responsive layout; `.onboarding-card` with border, padding, rounded corners; `.onboarding-card .state-icon` large icon display; color-coded border-left per severity (green for available/success, amber for degraded, red for error)

**Checkpoint**: Navigate to Settings → Workspace. Click "Show onboarding flow." Verify 8 cards render with distinct visual treatments. No JS errors.

---

## Phase 6: User Story 4 — Workspace Sync Status and Indexing States (Priority: P4)

**Goal**: Toolbar sync pill shows 4 distinct states. File path chips have per-file sync badges. A loading/indexing view exists with file count and progress.

**Independent Test**: Observe toolbar sync pill. Go to Settings → Workspace — cycle sync state through 4 values and confirm toolbar updates. Open any detail inspector view with a file path chip — confirm sync badge is present. Navigate to the indexing state view — confirm file count, progress bar, and a classification warning are shown.

- [x] T021 [US4] Update sync pill CSS in `prototype/styles.css`: add `.sync-pill[data-state="synced"]` (green background), `[data-state="syncing"]` (blue, animated pulse), `[data-state="stale"]` (amber), `[data-state="error"]` (red) — each with a distinct icon or unicode character before the label text
- [x] T022 [US4] Update sync pill rendering in `prototype/app.js` to read from `state.syncState` and set `data-state` attribute on the pill element; update `renderSidebar()` (or wherever the pill renders post-T008 move to toolbar) to call this on each render
- [x] T023 [US4] **Append** a "Cycle sync state" button to the existing content in `viewSettingsWorkspace()` in `prototype/app.js` — do not replace the "Show onboarding flow" button added by T019; the button increments `state.syncState` through `['synced','syncing','stale','error']` and calls the pill re-render
- [x] T024 [US4] Add per-file sync badge CSS to `prototype/styles.css`: `.path-chip` gets a `::after` pseudo-element (or a `.sync-badge` child span) showing a small colored dot; add `.sync-badge--available` (green dot), `.sync-badge--syncing` (blue dot), `.sync-badge--missing` (amber dot), `.sync-badge--conflict` (red dot)
- [x] T025 [US4] Add `viewIndexingProgress()` function to `prototype/app.js`: renders a centered progress view showing mock "Indexing workspace" title, a progress bar at ~60%, a file count ("47 of 83 files scanned"), and one mock classification warning row; then **append** a "Show indexing state" button to the existing content in `viewSettingsWorkspace()` that calls `navigate('indexing-progress')` — do not replace existing Settings Workspace content added by T019 and T023

**Checkpoint**: Toolbar sync pill visible on all views. Cycling states in Settings changes pill appearance. At least one detail inspector view shows a path chip with a sync badge. Indexing state view renders without errors.

---

## Phase 7: User Story 5 — Validation Issue Card and Repair Preview Panel (Priority: P5)

**Goal**: Issues table rows show severity + file path + repairable badge. Repairable inspector shows diff preview. Manual inspector shows no Apply button.

**Independent Test**: Go to Overview Issues table. Read a row: severity icon, file path, description, badge visible. Select a repairable issue: inspector shows before/after rows, backup note, Apply/Cancel. Select a manual issue: no Apply button, Reveal in Finder and Open in Editor actions shown.

**⚠️ Execution order within this phase**: T026 (data) MUST complete before T027 and T028. T027 and T028 both read `issue.filePath`, `issue.repairPreview`, and `issue.severity` from `DATA.issues` — those fields do not exist until T026 adds them.

- [x] T026 [US5] Extend `DATA.issues` in `prototype/data.js` to ensure at least 3 repairable issues and 2 manual-only issues exist; add `filePath`, `repairPreview: { before: string, after: string }`, and `severity: 'error'|'warning'|'info'` fields to each issue entry
- [x] T027 [P] [US5] Add severity icon/color CSS to `prototype/styles.css`: `.issue-row--error` (red left border, red icon), `.issue-row--warning` (amber), `.issue-row--info` (blue); `.issue-badge--repairable` (green pill), `.issue-badge--manual` (grey pill)
- [x] T028 [US5] Update the issues table row render logic in `prototype/app.js` (wherever `DATA.issues` is iterated for table display — both in Overview and the existing Issues views): each row must render severity indicator, `issue.filePath` in a `.path-chip` span, `issue.description`, and a repairable/manual badge; rows must call `openInspector('issue', issue.id)` on click
- [x] T029 [US5] Update `renderInspector()` in `prototype/app.js` for `kind === 'issue'`: if `issue.repairable === true`, render a diff-style panel (two side-by-side divs: "Before" and "After" with mock row text from `issue.repairPreview`), a backup confirmation note ("A timestamped backup will be created before applying"), and Apply/Cancel buttons; if `issue.repairable === false`, render an explanation paragraph and Reveal in Finder + Open in Editor action buttons — no Apply button

**Checkpoint**: Overview Issues table shows all three severity levels with distinct styling. Selecting a repairable issue shows diff + Apply. Selecting a manual issue shows no Apply. No JS errors.

---

## Phase 8: User Story 6 — Overview Dashboard (Priority: P6)

**Goal**: No filter bar on Overview. Exactly 5 KPI cards. Inline Issues table below charts.

**Independent Test**: Navigate to Overview. No filter bar visible. Count KPI cards: exactly 5 (Budget, Savings, Investments, Business, Taxes). Scroll down: Issues table present with severity-grouped rows. Click any KPI card: navigates to correct module.

- [x] T030 [US6] Update `viewOverviewDashboard()` in `prototype/app.js`: remove the `renderFilterBar([...])` call entirely (FR-017); do not pass any filter configuration to this view
- [x] T031 [US6] Update the KPI card array in `viewOverviewDashboard()` to contain exactly 5 cards: Budget (monthly cash flow), Savings (total savings balance), Investments (total investment value), Business (YTD net income), Taxes (estimated return); remove any extra cards; each card's `onclick` must call `navigate()` to the corresponding module's top-level view
- [x] T032 [US6] Add an inline Issues section to `viewOverviewDashboard()` below the charts: reuse the issue row render logic from T027; group by severity (errors first, then warnings, then info); display issue count badge per group

**Checkpoint**: Overview loads with no filter bar, 5 KPI cards, and a populated Issues table. Clicking each card navigates to the right module. No JS errors.

---

## Phase 9: User Story 7 — Budget Module Updated (Priority: P7)

**Goal**: Budget Overview shows pie chart and trailing average column. No Rules anywhere.

**Independent Test**: Navigate to Budget → Overview. Pie/donut chart visible showing spending breakdown. Category table has a "3M Avg" column. Search for "Rules" in sidebar: not present.

- [x] T033 [US7] Add `viewBudgetOverview()` function to `prototype/app.js` (rename or replace the existing `viewBudgetCurrent()` function): first search app.js for an existing `donutChart` function — if found, call it with mock percentages for Fixed, Discretionary, Savings, Investments as share of net monthly income; if `donutChart` does not exist, implement a minimal inline donut SVG using `lineChart` as a structural reference and name it `donutChart` before calling it
- [x] T034 [US7] Update the category variance table inside `viewBudgetOverview()` to add a "3M Avg" column alongside Planned, Actual, Variance; use mock trailing average values from `DATA.budgets` or add a `trailingAvg` field; for categories with fewer than 3 months of data, show the partial value with a `*` or `~` prefix and a footnote
- [x] T035 [US7] Update `renderCenter()` dispatch in `prototype/app.js` to route `budget-overview` to `viewBudgetOverview()` (replacing any existing `personal-budget-current` routing)

**Checkpoint**: Navigate to Budget → Overview. Donut chart renders. Category table shows 4 columns including 3M Avg. NAV has no Rules entry. No JS errors.

---

## Phase 10: User Story 8 — Savings & Investments Unified Module (Priority: P8)

**Goal**: Single Savings & Investments section in sidebar. Benchmarks shows heat map table with 8 period columns.

**Independent Test**: Sidebar shows no separate "Savings Goals" or "Investments" sections. Navigate to Savings & Investments → Portfolio → Benchmarks. Heat map table renders with exactly 8 column headers: D, W, M, 3M, 6M, 1Y, 3Y, 5Y. Each cell shows a % value or a dash. No line chart.

- [x] T036 [US8] Add `heatMapTable(rows, periods)` helper function to `prototype/app.js`: returns a `<table>` element; header row = period labels; data rows = account name + one cell per period; cells get class `pos` for positive returns, `neg` for negative, no class for null (shows `—`); include an S&P 500 comparison row with a visual separator
- [x] T037 [US8] Update `viewInvestmentsBenchmarks()` in `prototype/app.js` to call `heatMapTable(DATA.benchmarkReturns, DATA.benchmarkPeriods)` instead of `lineChart()`; remove the existing line chart call
- [x] T038 [US8] Add heat map table CSS to `prototype/styles.css`: `.heat-map-table` with fixed column widths; `.heat-map-table td.pos` with light green background; `.heat-map-table td.neg` with light red background; `.heat-map-table .sp500-row` with a top border separator; responsive minimum column width for 8 columns

**Checkpoint**: Benchmarks view shows a table, not a line chart. 8 period columns visible. Positive cells green-tinted, negative red-tinted. No JS errors.

---

## Phase 11: User Story 9 — Taxes Expanded and Accounts Placeholder (Priority: P9)

**Goal**: Current Tax Year shows deduction groups inline (not as a separate screen), plus a per-account rate table. Accounts section renders a card grid.

**Independent Test**: Taxes → Current Tax Year: scroll past estimated payments and gains panels to confirm 4 labeled deduction group sections appear inline (Standard, Above-the-Line, Schedule A, Schedule C); per-account rate table visible. Accounts: card grid with ≥2 account cards, each showing name, group label, and placeholder values.

*(Note: T039 as originally written described a standalone `viewTaxesDeductions()` view. The implementation was corrected per FR-023 — deductions are rendered inline via `appendDeductionGroups(c)` appended to `viewTaxesCurrent()`. A standalone deductions route does not exist.)*

- [x] T039 [US9] Add `appendDeductionGroups(c)` function to `prototype/app.js`: called at the end of `viewTaxesCurrent()` to append 4 labeled deduction group panels inline — Standard Deduction, Above-the-Line Deductions, Schedule A — Itemized Deductions, Schedule C — Self-Employment Deductions. Each group shows a table with `Deduction`, `Estimated Amount`, `Status` columns and a totals row. Deduction rows are read-only (no inspector, no click handler). **Not** a standalone route.
- [x] T040 [US9] Update `viewTaxesCurrent()` in `prototype/app.js` to append a per-account effective rate table below existing content using `DATA.accountTaxRates`; columns: Account, Taxable Income, Taxes Paid, Taxes Owed, Effective Rate; format rate as percentage
- [x] T041 [US9] Add `viewAccounts()` function to `prototype/app.js`: renders an aggregate header row (sum of monthlyInflow, sum of ytdNetIncome across all accounts) followed by a card grid from `DATA.accounts`; each card shows account name, institution, group label badge, and placeholder values; include an empty state when `DATA.accounts` is empty

**Checkpoint**: All three views render with mock data. Deductions shows 4 sections. Tax rate table has all columns. Accounts card grid shows 4 mock accounts. No JS errors.

---

## Phase 12: Polish & Cross-Cutting Concerns

**Purpose**: CSS consistency, edge-case states, and final manual walkthrough.

- [x] T042 [P] Add empty-state handling to `viewAccounts()` in `prototype/app.js`: if `DATA.accounts` is empty, render a centered empty state card with "No accounts added" text and an "Add account (coming soon)" placeholder button (SC-002 / edge case from spec)
- [x] T043 [P] Add empty-state handling to `viewBudgetOverview()` in `prototype/app.js`: if all donut chart values are zero, render an empty state message ("No transactions this month") inside the chart area instead of a broken or invisible donut
- [x] T044 [P] Polish heat map table cell alignment and spacing in `prototype/styles.css`: right-align all value cells; bold the S&P 500 row; ensure column headers are centered; add a light divider between account rows and S&P row
- [x] T045 [P] Add `sync-badge` spans to existing file path chips in the inspector render logic in `prototype/app.js`: every `.path-chip` rendered in inspector views must include a `<span class="sync-badge sync-badge--available">` child so reviewers see the badge design in context
- [x] T046 Manual review: open `prototype/index.html` in browser; open DevTools console; navigate every sidebar section; confirm zero JS errors (SC-003); confirm right panel absent on load (SC-006); confirm no V2-deferred views reachable (SC-002); confirm 5 KPI cards on Overview; confirm Benchmarks shows table not chart

**Checkpoint**: Zero JS console errors. All 9 user stories manually verified per their Independent Test criteria. quickstart.md review guide walkthrough passes.

---

## Dependencies & Execution Order

### Phase dependencies

- **Phase 1** (data): No dependencies — start immediately
- **Phase 2** (foundational): Depends on Phase 1 ✅ — state, shell, and inspector helpers must exist before any view work
- **Phase 3** (US1 — navigation): Depends on Phase 2 ✅ — NAV rewrite and dispatch table need inspector helpers
- **Phases 4–11** (US2–US9): All depend on Phase 3 ✅ — nav structure must be correct before any view is meaningful
- **Phase 12** (polish): Depends on Phases 3–11 completing ✅

### User story dependencies (within Phases 4–11)

All US2–US9 phases depend on Phase 3 (US1). After that, they are **independent** of each other:

- US2 (inspector), US3 (onboarding), US4 (sync status), US5 (issue cards) — no cross-dependencies
- US6 (Overview) depends on US5 (issue card design must exist before Overview can embed it)
- US7, US8, US9 — fully independent once Phase 3 complete

### Recommended sequential order (single developer)

Phase 1 → Phase 2 → Phase 3 → Phase 4 (US2) → Phase 7 (US5) → Phase 8 (US6) → Phase 5 (US3) → Phase 6 (US4) → Phase 9 (US7) → Phase 10 (US8) → Phase 11 (US9) → Phase 12

---

## Parallel Execution Examples

### Phase 1 (all 5 tasks parallel)

```
T001 DATA.accounts
T002 DATA.iCloudStates
T003 DATA.benchmarkReturns
T004 DATA.deductions
T005 DATA.accountTaxRates
```

### Phase 2 (T007 + T008 parallel after T006)

```
T006 Update state object  →  T007 Inspector CSS
                          →  T008 index.html shell
                          →  T009 openInspector/closeInspector helpers
                          →  T010 navigate() hook
```

### Phases 5–11 (fully parallelizable after Phase 3)

```
US3 Onboarding (T018-T020)
US4 Sync status (T021-T025)
US5 Issue cards (T026-T029)   →   US6 Overview (T030-T032)
US7 Budget (T033-T035)
US8 S&I (T036-T038)
US9 Taxes + Accounts (T039-T041)
```

---

## Implementation Strategy

### MVP (US1 only — Phases 1, 2, 3)

1. Complete Phase 1: Add mock data to `data.js`
2. Complete Phase 2: State, HTML shell, inspector helpers
3. Complete Phase 3: NAV rewrite and default view
4. **STOP AND VALIDATE**: Open prototype, read sidebar, confirm nav matches spec

### Incremental delivery

Each phase (US2 through US9) adds one independently verifiable story. After each phase, run the Independent Test for that story before moving on.

### Total task count

| Phase | Tasks | User Story |
|---|---|---|
| Phase 1: Setup | 5 | — |
| Phase 2: Foundational | 5 | — |
| Phase 3 | 4 | US1 |
| Phase 4 | 3 | US2 |
| Phase 5 | 3 | US3 |
| Phase 6 | 5 | US4 |
| Phase 7 | 4 | US5 |
| Phase 8 | 3 | US6 |
| Phase 9 | 3 | US7 |
| Phase 10 | 3 | US8 |
| Phase 11 | 3 | US9 |
| Phase 12: Polish | 5 | — |
| **Total (Round 1)** | **46** | |
| Phase 13: Persistence | 3 | US10 |
| Phase 14: Interaction Infrastructure | 3 | US10–11 |
| Phase 15: Create Flows | 5 | US11–12 |
| Phase 16: Repair, Checklist, Reindex | 3 | US5 (extended), US10 |
| Phase 17: Export Shapes | 5 | US13 |
| Phase 18: Settings & Review Controls | 1 | US10 |
| Phase 19: Live Search | 3 | US14 |
| Phase 20: Entity Dashboards & Tax Archive | 2 | US9 (extended) |
| Phase 21: Inspector & Routing | 4 | — |
| Phase 22: Smoke Test | 1 | SC-013 |
| **Total (Round 1 + Round 5)** | **76** | |

---

## Notes

- [P] tasks = independent work that can be done in parallel (different sections of app.js or different files)
- Each user story phase ends with an **Independent Test** that can be run immediately after that phase completes
- Commit after each phase checkpoint — gives clean rollback points per user story
- `renderCenter()` dispatch table is the central routing hub; keep it in sync with NAV changes
- Round 1 tasks (T001–T046): manual verification only. Round 5 (T047–T076): SC-013 smoke test adds a headless gate.

---

## Phase 13: Round 5 — Persistence Layer (US-10, FR-026–030, FR-062–063)

**Purpose**: Add `store.js` module and `commit()` write pipeline. All subsequent Round 5 flows depend on this.

All tasks complete [x] — implemented during the Round 5 interactive pass (2026-06-14).

- [x] T047 [US10] Create `prototype/store.js`: expose `Store.hydrate()`, `Store.save()`, `Store.reset()`, `Store.isDirty()`, `Store.syncDerived()`. Storage key: `finance-proto-workspace-v1`. `hydrate()` overlays 16 mutable collections from localStorage onto seed DATA; `syncDerived()` recomputes `DATA.businessTransactions`. Load order in `index.html`: `data.js → store.js → app.js`. (FR-026–029)
- [x] T048 [US10] Add `commit()` to `prototype/app.js`: calls `Store.save() → renderSidebar() → renderCenter() → renderInspector()` in order. Every DATA mutation MUST call `commit()` — never mutate DATA and re-render directly. (FR-030)
- [x] T049 [US10] Update `viewSettingsWorkspace()` in `prototype/app.js`: add a live dirty-state note (reads `Store.isDirty()`); add "Reset prototype data" as `.btn.btn-danger` that calls `openModal()` for confirmation, only calling `Store.reset()` on confirm. (FR-062, FR-063)

**Checkpoint**: Add a goal in the browser, reload — goal persists. Click "Reset prototype data", cancel — data unchanged. Confirm — page reloads with seed data. No JS errors.

---

## Phase 14: Round 5 — Interaction Infrastructure (FR-031–035)

**Purpose**: Reusable modal, toast, and menu primitives. All create/import flows depend on these.

- [x] T050 [US11] Add `openModal({ title, subtitle, fields, body, submitLabel, cancelLabel, onSubmit })` to `prototype/app.js`. Fields: `text`, `number`, `date`, `select`, `textarea`. Required fields show `field-error` on empty submit; `onSubmit` returns `true` to close or `false` to keep open. (FR-031)
- [x] T051 Add `toast(message, kind)` and `openMenu(anchor, options, onPick)` to `prototype/app.js`. Toast appends to `.toast-host`, auto-dismisses; kinds: `ok` / `warn` / `info`. Menu positions `.proto-menu` relative to anchor, closes on outside click. (FR-032, FR-033)
- [x] T052 Wire filter bar chips in `prototype/app.js`: chips with an `options` array call `openMenu` on click; chips without options call `toast` fallback. Add `osAction(label, target)` function that shows an `info` toast for OS-level operations (Reveal in Finder, Open in editor, file downloads). (FR-034, FR-035)

**Checkpoint**: Click a filter chip with options — dropdown appears. Click outside — closes. Click "Reveal in Finder" in any inspector — toast appears. No JS errors.

---

## Phase 15: Round 5 — Create Flows (US-11, US-12, FR-036–045)

**Purpose**: All new-entity and import flows. Each opens a modal, validates required fields, and calls `commit()`.

- [x] T053 [US11] Add create modals to `prototype/app.js` for goal (FR-036), category (FR-038), account/asset (FR-040), and entity (FR-039). Each pushes to the corresponding `DATA` collection, updates any related badge or aggregate, and calls `commit()`. Required field validation must block submit.
- [x] T054 [US12] Add `ingestTransactionCSV(text, { entityId, business })` and `addTransaction(v)` to `prototype/app.js`. Wire "Import CSV" modal (FR-037): file upload accepts `.csv`, format hint shows `date, merchant, description, category, amount`; manual-entry form is the fallback. CSV read via FileReader; valid rows call `addTransaction` and `commit()`. Warn toast on empty result; warn toast if neither file nor merchant+amount provided.
- [x] T055 [US11] Add Import Paystub modal to employment entity dashboard (FR-041): fields Pay period, Gross pay, Net pay — adds payroll credit to `DATA.transactions`, calls `commit()`. Add New estimated payment modal to Taxes (FR-042): fields Quarter, Year, Jurisdiction, Due date, Amount — pushes to `DATA.estimatedPayments` with `status: 'pending'`, calls `commit()`. Add Import prices modal to Portfolio/Holdings (FR-043): select holding ticker, new price — updates `holding.price`, calls `commit()`.
- [x] T056 [US11] Add Rebalance plan modal to Portfolio (FR-044): compute drift = actual weight − target weight per sleeve; show only |drift| > 0.5%; "Export plan" downloads `rebalance-plan.csv` with columns `ticker, sleeve, drift, trade_usd`.
- [x] T057 [US11] Add Business Categories "New" modal (FR-045): Name (required), Group — pushes to `DATA.businessCategories`, calls `commit()`.

**Checkpoint**: Add goal via New Goal modal — appears immediately. Import a valid CSV on Budget screen — rows appear; reload — rows persist. Required-field error blocks submit. No JS errors.

---

## Phase 16: Round 5 — Repair, Checklist, Reindex (FR-046–049)

**Purpose**: Extend existing repair wiring to persist, add checklist toggle, and add reindex flow.

- [x] T058 [US5-extended] Add `applyRepair(id)` to `prototype/app.js` (FR-046): removes issue from `DATA.issues`, decrements `DATA.workspace.issueCount`, closes inspector, toasts "1 issue repaired · backup saved", calls `commit()`. Add Overview "Apply repairable fixes" action (FR-047): bulk-removes all repairable issues, toasts "{n} issues repaired · backups saved", calls `commit()`. If none repairable: `info` toast.
- [x] T059 [US10] Add `toggleChecklistItem(id)` to `prototype/app.js` (FR-048): flips the `done` field on the matching item in `DATA.taxChecklist`, calls `commit()`. Checklist item click handler calls `toggleChecklistItem`. State persists on reload.
- [x] T060 Add `runReindex()` to `prototype/app.js` (FR-049): sets `state.syncState = 'syncing'`, re-renders sidebar, waits ~2s, sets `state.syncState = 'synced'`, re-renders, shows `info` toast. Wire to all Reindex buttons.

**Checkpoint**: Apply a repair — issue disappears, count decrements, reload confirms removal. Toggle checklist item — reloads with same state. Reindex shows syncing animation then returns to synced.

---

## Phase 17: Round 5 — Export Shapes (US-13, FR-050–060)

**Purpose**: All 11 export surfaces produce real file downloads from live DATA using `exportCSV` / `exportMarkdown`.

- [x] T061 Add `exportCSV(filename, headers, rows)` and `exportMarkdown(filename, md)` to `prototype/app.js`: Blob + URL.createObjectURL downloads. `toCSV(headers, rows)` handles RFC 4180 escaping. Wire Budget Overview export → `transactions-2026-05.csv` (FR-050), Budget History export → `budget-history.csv` (FR-051), Budget Categories export → `categories.csv` (FR-052).
- [x] T062 Wire Savings Goals export → `savings-goals.csv` (FR-053). Wire Portfolio Overview export → `holdings.csv` with `market_value` computed column (FR-054). Wire Holdings export → `holdings.csv` without market_value (FR-055).
- [x] T063 Wire Overview Issues export → `overview-issues.csv` (FR-056). Wire Rebalance plan "Export plan" → `rebalance-plan.csv` (FR-057).
- [x] T064 Wire Business / Account Entity "Export P&L" → `{entityId}-pl.md` Markdown with Revenue/Expenses/Net summary + Transactions table (FR-058). Wire Taxes "Export prep packet" → `2026-tax-prep-packet.md` with GFM checklist + Estimated Payments + Deductions tables (FR-059).
- [x] T065 Wire Accounts Overview export → `accounts.csv` with columns `name, institution, group, type, entity, monthly_inflow, ytd_net_income` (FR-060). Warn toast on all exports when the target collection is empty.

**Checkpoint**: Click every Export button on a populated dataset — file downloads in each case. Add a goal, export savings-goals.csv — new goal appears in the file. No export button shows a broken state.

---

## Phase 18: Round 5 — Prototype Review Controls (FR-061)

- [x] T066 [US10] Add clearly labeled "Prototype Review Controls" section to `viewSettingsWorkspace()` in `prototype/app.js` (FR-061). Must include disclaimer: *"These buttons control prototype state for design review. They do not represent real app functionality."* Four controls in order: Show onboarding flow (navigate), Cycle sync state (cycle and re-render), Show indexing state (navigate), Reset prototype data (danger button → T049 confirmation flow). Visually separate this section from real Settings content.

**Checkpoint**: Settings → Workspace shows the Review Controls section with the disclaimer text. All four buttons respond correctly. Section is visually distinct from non-prototype settings.

---

## Phase 19: Round 5 — Live Search (US-14, FR-064–066)

- [x] T067 [US14] Add search input to Savings Goals view in `prototype/app.js` (FR-064): text input above goal cards; on `input` event filter `DATA.goals` by name (case-insensitive substring); re-render only matching cards; clearing input restores all cards.
- [x] T068 [US14] Add search input to Holdings view in `prototype/app.js` (FR-065): filters holding rows by ticker or name (case-insensitive) on `input` event.
- [x] T069 [US14] Add search input to Budget transaction ledger and Business entity transaction ledger in `prototype/app.js` (FR-066): filters table rows by any text column content (case-insensitive) on `input` event.

**Checkpoint**: Type in Savings Goals search — only matching cards shown. Clear — all cards return. Type in Holdings — only matching rows shown. Type in Budget ledger — matching rows only.

---

## Phase 20: Round 5 — Entity Dashboards and Tax Archive (FR-067–068)

- [x] T070 [US9-extended] Update `viewAccountEntity()` in `prototype/app.js` (FR-067): business entities show a 4-tab bar (Dashboard, Transactions, Budgets, Categories); employment entities show 2 tabs (Dashboard, Transactions); personal entities show Dashboard only. Tab state stored in `state.entityTabs[entityId]` — session-only, NOT in `PERSIST_KEYS`, resets to `'dashboard'` on reload. Import CSV and Export P&L actions available on business entity dashboards.
- [x] T071 Update `viewTaxesArchive()` in `prototype/app.js` (FR-068): renders a read-only table of prior closed tax years — columns: Tax year, Closed date, Total deductions, Total estimated payments, Archive file path chip. No edit/delete affordances. "Close Tax Year" action is deferred (locked decision per `technical-design.md §21`) — no button.

**Checkpoint**: Navigate to a business entity — 4-tab bar shown. Switch tabs — content changes. Reload — tab resets to Dashboard. Taxes → Tax Archive — read-only table renders. No Close Tax Year button.

---

## Phase 21: Round 5 — Inspector and Legacy Routing (FR-069–072)

- [x] T072 Add `account` inspector kind to `renderInspector()` in `prototype/app.js` (FR-069): Monthly Inflow (large value display), Account details (Institution, Type, Group, YTD net income), Source section linking to `Accounts/accounts.csv`. Triggered when an account card is clicked in Accounts view.
- [x] T073 Ensure `renderInspector()` in `prototype/app.js` handles all 13 kinds in the FR-070 catalog: `transaction`, `category`, `rule`, `goal`, `holding`, `sleeve`, `biz-tx`, `issue`, `note`, `account`, `estimatedPayment`, `realized`, `overview-kpi`. All other kinds fall to generic fallback. Verify no kind in the catalog is missing a handler.
- [x] T074 Ensure `renderCenter()` in `prototype/app.js` contains the full legacy redirect map from FR-071: `savings-goals-active / savings-goals-archived → savings-goals`; `investments-accounts / investments-sleeves / savings-accounts → investments-portfolio`; `investments-benchmarks / investments-benchmark → investments-holdings`; `business-entity / business-all-entities / business-monthly → viewBusiness()`; `taxes-deductions / taxes-estimated / taxes-gains / taxes-estimated-payments / taxes-gains-income → taxes-current`. Redirects must be silent (no toast).
- [x] T075 Ensure `viewNotes()`, `viewIssues()`, and `viewBudgetRules()` remain as unreachable stub functions in `prototype/app.js` — NOT in the NAV array (FR-072). Search inputs in `viewNotes` and `viewIssues` use `onChange: () => {}` no-ops intentionally.

**Checkpoint**: Click an account card — `account` inspector slides in with correct layout. Navigate to `/investments-benchmarks` (legacy) — Holdings screen loads. No 13-kind inspector handler is missing. V2 stubs not reachable from sidebar.

---

## Phase 22: Round 5 — Smoke Test (SC-013)

- [x] T076 Run jsdom headless smoke test from `/tmp/protosmoke` (see `prototype/README.md §Smoke test` for setup instructions): concatenate `data.js + store.js + app.js`, eval in jsdom context, assert 19 outcomes: initial render, add-goal → DATA → badge → card → persist, apply-repair, checklist toggle, manual transaction import, CSV export, filter-menu click, all nav + entity views without error, persistence across simulated reload. **Target: 19/19 passing.** *(Committing `prototype/smoke.js` to the repo is a P4 Known Gap — see `spec.md §Known Gaps`.)*

**Checkpoint**: 19/19 assertions pass. Any failure is a regression to investigate before the round is closed.
