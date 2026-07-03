# Tasks: Presentation Layer — App Shell & All Module Views (Phase 5)

**Input**: Design documents from `specs/006-presentation-layer/`
**Prerequisites**: plan.md, spec.md (8 user stories), research.md (D1–D8), data-model.md,
contracts/ (app-shell, components, module-views, app-target), quickstart.md

**Tests**: Included per plan §Testing / research D8 — unit tests below the view body
(router/store/view models/command matrix) in the new `FinanceWorkspaceAppTests` SwiftPM target;
view rendering verified via mandatory light+dark `#Preview`s and the Milestone-5 manual demo.
No XCUITest in this phase.

**Organization**: Grouped by user story. **US1 (shell) strictly blocks all module stories; US2
(components) blocks US3–US7; US3–US7 are then parallelizable; US8 lands last.** Every view task
must clear the `design-adherence` gate and use only `DesignSystem` tokens (FR-033); no view may
compute finance figures (FR-031); zero workspace writes anywhere (FR-032).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1–US8 from spec.md

## Phase 1: Setup (DesignSystem token layer + test target)

**Purpose**: The token-to-code translation point every view consumes (scaffold-skill
precondition), plus the app test target.

- [ ] T001 Add `FinanceWorkspaceAppTests` test target to `Package.swift` (depends on
      `FinanceWorkspaceApp`), with an empty smoke test in
      `Tests/FinanceWorkspaceAppTests/SmokeTests.swift`; `swift build` + `swift test` stay green
- [ ] T002 [P] Create `Sources/FinanceWorkspaceApp/DesignSystem/Tokens.swift` — every DESIGN.md
      front-matter color as a light/dark dynamic `Color`, plus radius, spacing scale, row height,
      sidebar/detail-pane/min-window metrics, shadows/materials
- [ ] T003 [P] Create `Sources/FinanceWorkspaceApp/DesignSystem/Typography.swift` — the 8-step
      type scale (page-title…caption) with `.monospacedDigit()` on all numeric styles
- [ ] T004 [P] Create `Sources/FinanceWorkspaceApp/DesignSystem/Components/` base styles —
      `StatusChipStyle`, `TagStyle`, primary/secondary/ghost `ButtonStyle`s, `PanelView` chrome
      (panel-head + panel-body), filter-pill style
- [ ] T005 Run the `design-adherence` gate + `design-token-sync` audit over the new token layer
      against `DESIGN.md` front matter and `prototype/styles.css`; fix any drift (update
      `DESIGN.md` + Changelog first if a needed token is missing)

---

## Phase 2: Foundational (projection snapshot + presentation primitives)

**Purpose**: Blocking prerequisites for every story — the read-model snapshot and the shared
traceability/formatting primitives.

**⚠️ CRITICAL**: No user story work until this phase completes.

- [ ] T006 [P] Create `Sources/FinanceWorkspaceApp/UI/Shared/PresentationModels.swift` —
      `SourceRef`, `Provenance`, `Delta`, typed-state display helpers, and tabular
      currency/percent/date formatters (per data-model.md)
- [ ] T007 Create `WorkspaceProjections` immutable snapshot (dashboard, per-module projections,
      issues, retained `WorkspaceContext`, builtAt/asOf) in
      `Sources/FinanceWorkspaceApp/ProjectionStore.swift`
- [ ] T008 Implement `ProjectionStore` in `Sources/FinanceWorkspaceApp/ProjectionStore.swift` —
      off-main parse via `WorkspaceParser` → run all nine engines + `ValidationEngine` → single
      main-actor snapshot swap; `LoadPhase` (idle/indexing/ready/failed); `rebuild()` keeps the
      previous snapshot visible until swap (FR-036, research D3)
- [ ] T009 [P] Write `Tests/FinanceWorkspaceAppTests/ProjectionStoreTests.swift` — atomic-swap
      semantics, typed-state passthrough, and the read-only guarantee: workspace files
      byte-identical before/after a full store lifecycle against a fixture (SC-005)

**Checkpoint**: Snapshot + primitives ready — US1 can begin.

---

## Phase 3: User Story 1 — App shell, navigation & detail pane (P1) 🎯 MVP

**Goal**: Launchable shell — Overview landing, sidebar, header chips, detail pane, §17 menus —
with placeholder module content.

**Independent Test**: `swift run FinanceWorkspaceApp` against a fixture workspace: Overview
landing (no sidebar Overview row), sidebar expand/select/keyboard nav, live issues+sync chips,
pane open/close via selection and ⌥⌘I, menu matrix enabled/disabled as contracted, deep-link
round trip.

- [ ] T010 [US1] Create `Route` enum + `BudgetSubview`/`SISubview`/`TaxSubview` + stale-ID
      fallback rules in `Sources/FinanceWorkspaceApp/AppRouter.swift` (data-model.md)
- [ ] T011 [US1] Implement `RouteActivityCodec` (versioned `NSUserActivity` user-info dict,
      activity type `app.openfinance.navigation`; session selectors excluded) in
      `Sources/FinanceWorkspaceApp/AppRouter.swift` (research D6)
- [ ] T012 [P] [US1] Write `Tests/FinanceWorkspaceAppTests/AppRouterTests.swift` — route⇄activity
      round-trip for every case, stale-entity fallback to parent module, KPI→route mapping
- [ ] T013 [US1] Extract and extend `AppState` into `Sources/FinanceWorkspaceApp/AppState.swift`
      — keep provider/manager wiring; add `phase`, `projections`, `route` (`.overview` initial),
      `sidebarExpansion`, `DetailPaneState`, `SessionSelections` (session-only, clarify Q1)
- [ ] T014 [US1] Implement `AppRouter.navigate(to:)` + `route(forKPI:)` (sidebar/breadcrumb/pane
      sync; pane closes or re-scopes on navigation) in
      `Sources/FinanceWorkspaceApp/AppRouter.swift`
- [ ] T015 [US1] Build `NavigationSidebarView` in
      `Sources/FinanceWorkspaceApp/UI/Shell/NavigationSidebarView.swift` — "Finance Dashboard"
      header → `.overview`, no Overview row, expandable groups ("Account groups" with disabled
      "New group", Budget, Savings & Investments, Taxes), nested entity links, active
      accent-soft state, count badges, empty-group states, keyboard traversal (FR-004)
- [ ] T016 [P] [US1] Build `GlobalHeaderView` in
      `Sources/FinanceWorkspaceApp/UI/Shell/GlobalHeaderView.swift` — issues chip immediately
      left of sync chip, live from `projections.issues` + `phase`/provider sync state; issues
      chip tap → Overview (FR-005, FR-036)
- [ ] T017 [P] [US1] Build `BreadcrumbView` + `PageTitleActionsView` (right-aligned per-view
      local actions incl. disabled write actions) in
      `Sources/FinanceWorkspaceApp/UI/Shell/PageTitleActionsView.swift`
- [ ] T018 [US1] Build `DetailPaneView` via `.inspector(isPresented:)` (360–420 width, closed by
      default, surface switch over the 6 `DetailPaneSurface` cases, close button, disabled
      Edit/Delete at bottom) in `Sources/FinanceWorkspaceApp/UI/Shell/DetailPaneView.swift`
      (FR-006, research D1)
- [ ] T019 [US1] Rewrite `Sources/FinanceWorkspaceApp/FinanceWorkspaceApp.swift` — three-column
      `NavigationSplitView` scene (min window 900), `.commands` menu matrix per
      contracts/app-shell.md (§17 + D5; Phase-6 commands present-disabled), `.userActivity` /
      `.onContinueUserActivity` restoration, `ProjectionStore` bootstrap on launch, loading
      skeleton phase; replace the diagnostic `ContentView` (module slots = placeholders)
- [ ] T020 [P] [US1] Write `Tests/FinanceWorkspaceAppTests/CommandMatrixTests.swift` — menu
      enable/disable matrix (Phase-6 commands disabled; selection-context commands gated)
- [ ] T021 [US1] Shell checkpoint: run against fixture + empty workspaces (US1 acceptance
      scenarios 1–6), fix gaps, clear the `design-adherence` gate over all `UI/Shell/` views;
      light+dark `#Preview`s on every shell view

**Checkpoint**: Fully navigable shell (placeholder content) — MVP demoable.

---

## Phase 4: User Story 2 — Shared component library (P1)

**Goal**: The complete `UI/Shared/` component set, previewable with fixture data, before any
module composes it.

**Independent Test**: Each component renders in light+dark `#Preview`s with representative and
empty/degenerate fixture data; charts are Swift Charts; inspector actions reveal real files.

- [ ] T022 [P] [US2] Build `KPICardView` (`KPICardModel`: overline, tabular value, delta
      pos/neg/flat, whole-card tap → route, typed-state rendering) in
      `Sources/FinanceWorkspaceApp/UI/Shared/KPICardView.swift`
- [ ] T023 [P] [US2] Build `DataTableView` (column specs, sticky uppercase header, 30 px rows,
      right-aligned tabular numerics, sort, hover/selected states, row → `SourceRef` target) in
      `Sources/FinanceWorkspaceApp/UI/Shared/DataTableView.swift`
- [ ] T024 [P] [US2] Build `PieChartView` (SectorMark donut + legend/labels), `SparklineView`
      (LineMark, short wrap), `BarChartView` (BarMark, pos/neg) under the `chart-styling` rules
      in `Sources/FinanceWorkspaceApp/UI/Shared/Charts.swift`
- [ ] T025 [P] [US2] Build `HeatMapTableView` (`Grid`-based: sticky row headers, 8 period
      columns, benchmark comparison row, pos/neg cell scale + tabular % text, typed
      insufficient-history cells, row selection) in
      `Sources/FinanceWorkspaceApp/UI/Shared/HeatMapTableView.swift` (research D4)
- [ ] T026 [P] [US2] Build `PeriodSelectorView` (month/quarter/year + prev/next, keyboard
      operable, session-scoped binding) in
      `Sources/FinanceWorkspaceApp/UI/Shared/PeriodSelectorView.swift`
- [ ] T027 [P] [US2] Build `EmptyStateView` + `LoadingSkeletonView` in
      `Sources/FinanceWorkspaceApp/UI/Shared/EmptyStateView.swift`
- [ ] T028 [P] [US2] Build `SourceInspectorView` (path, row, last-modified, raw fields; "Open in
      Finder"/"Open in Editor" via `NSWorkspace`; missing-source state disables both) in
      `Sources/FinanceWorkspaceApp/UI/Shared/SourceInspectorView.swift` (FR-012)
- [ ] T029 [P] [US2] Build `ValueProvenanceLabel` (imported/derived/repaired/user-edited) in
      `Sources/FinanceWorkspaceApp/UI/Shared/ValueProvenanceLabel.swift` (FR-013)
- [ ] T030 [US2] Build `LedgerTableView` — `LedgerEntry` grouping by `group_id` (summary row +
      disclosure to legs, each leg individually traceable, summary labeled derived) in
      `Sources/FinanceWorkspaceApp/UI/Shared/LedgerTableView.swift` (FR-020, research D7)
- [ ] T031 [US2] Component checkpoint: light+dark `#Preview`s + empty states on every component;
      `design-adherence` + `chart-styling` gates over `UI/Shared/`; zero hardcoded values
      (token audit)

**Checkpoint**: Component vocabulary complete — module stories can start (parallelizable).

---

## Phase 5: User Story 3 — Overview module (P1)

**Goal**: Live default landing — 5 KPI cards, MoM panel, issues table with read-only repair
preview.

**Independent Test**: Against the fixture workspace, all five cards match `overview-dashboard`
CLI values; card taps navigate; Preview Repair shows a dry-run diff and writes nothing.

- [ ] T032 [US3] Implement `OverviewViewModel` (dashboard → 5 `KPICardModel`s incl. `RateState`
      typed states, MoM `SparkPoint`s from the gap-skipping 6-mo series, severity-grouped issue
      rows with repairable badges) in
      `Sources/FinanceWorkspaceApp/UI/Overview/OverviewViewModel.swift`
- [ ] T033 [P] [US3] Write `Tests/FinanceWorkspaceAppTests/OverviewViewModelTests.swift` —
      card mapping (incl. "rate not set"), MoM series, issue grouping/count = chip count
- [ ] T034 [US3] Build `OverviewView` (KPI grid, no filters, MoM panel, inline issues table;
      KPI tap → module route) in `Sources/FinanceWorkspaceApp/UI/Overview/OverviewView.swift`
- [ ] T035 [US3] Build `OverviewIssuesTableView` + "Preview Repair" → `RepairService` dry-run →
      `.repairPreview` pane surface (no apply; no writes) in
      `Sources/FinanceWorkspaceApp/UI/Overview/OverviewIssuesTableView.swift` (FR-016)
- [ ] T036 [US3] Overview checkpoint: reconcile on-screen values with `overview-dashboard`
      (SC-001); US3 acceptance scenarios 1–4; `design-adherence` gate; light+dark previews

**Checkpoint**: Overview live end-to-end — shell + components + engine proven.

---

## Phase 6: User Story 4 — Accounts module (P2)

**Goal**: Three-level Accounts browsing with business P&L, grouped multi-entry ledgers, and
row-level traceability.

**Independent Test**: Fixture navigation grid → business group → per-account; values reconcile
with `accounts-overview`; multi-entry rows grouped; every ledger row opens the source inspector.

- [ ] T037 [US4] Implement `AccountsViewModel` (aggregate assets/liabilities header, group
      sections, account cards, group/account screen tables + chart series, `LedgerEntry`
      grouping, rules panel rows) in
      `Sources/FinanceWorkspaceApp/UI/Accounts/AccountsViewModel.swift`
- [ ] T038 [P] [US4] Write `Tests/FinanceWorkspaceAppTests/AccountsViewModelTests.swift` —
      aggregate math passthrough (no view-side computation), multi-entry grouping, business
      P&L section presence per `group_type`
- [ ] T039 [US4] Build `AccountsView` (card grid grouped by account group, aggregate net-worth
      header, card → account, group header → group) in
      `Sources/FinanceWorkspaceApp/UI/Accounts/AccountsView.swift` (FR-017)
- [ ] T040 [US4] Build `AccountGroupDetailView` (account cards above inline `LedgerTableView`,
      no sub-tabs; business: P&L summary, monthly net-income `BarChartView`, category budgets,
      linked-notes references) in
      `Sources/FinanceWorkspaceApp/UI/Accounts/AccountGroupDetailView.swift` (FR-018)
- [ ] T041 [US4] Build `AccountDetailView` (transactions ledger, monthly gross vs expenses/tax
      chart, YTD net income, rules & estimates panel; Import/Add/Edit/Delete visible-disabled)
      in `Sources/FinanceWorkspaceApp/UI/Accounts/AccountDetailView.swift` (FR-019)
- [ ] T042 [US4] Accounts checkpoint: reconcile with `accounts-overview` (SC-004); US4
      acceptance scenarios 1–5 incl. grouped paycheck expansion + row traceability;
      `design-adherence` gate; light+dark previews

---

## Phase 7: User Story 5 — Budget module (P2)

**Goal**: Budget overview (pie + 50/50 panels + category table + period selector), history, and
categories views with category drill-down.

**Independent Test**: Values reconcile with `budget-overview` across multiple selected periods;
category tap opens the filtered transaction view; selectors are session-scoped.

- [ ] T043 [US5] Implement `BudgetViewModel` (pie slices, spend-mix + variance panel models,
      category rows with plan/actual/variance/trailing-avg, period-driven engine re-run from the
      snapshot context, drill-down filter) in
      `Sources/FinanceWorkspaceApp/UI/Budget/BudgetViewModel.swift`
- [ ] T044 [P] [US5] Write `Tests/FinanceWorkspaceAppTests/BudgetViewModelTests.swift` — period
      switch recompute, partial-aware trailing-average passthrough, drill-down filter mapping
- [ ] T045 [US5] Build `BudgetOverviewView` (PieChartView, Spend Mix / Spending Variance at
      50/50, category `DataTableView`, `PeriodSelectorView`; category tap → filtered transaction
      list with traceable rows) in
      `Sources/FinanceWorkspaceApp/UI/Budget/BudgetOverviewView.swift` (FR-021)
- [ ] T046 [US5] Build `BudgetHistoryView` (MoM variance over a period range) +
      `BudgetCategoriesView` (category/subcategory list, create/edit visible-disabled) in
      `Sources/FinanceWorkspaceApp/UI/Budget/BudgetHistoryView.swift` and
      `Sources/FinanceWorkspaceApp/UI/Budget/BudgetCategoriesView.swift` (FR-022)
- [ ] T047 [US5] Budget checkpoint: reconcile with `budget-overview` for ≥2 periods (SC-004);
      US5 acceptance scenarios 1–4; `design-adherence` gate; light+dark previews

---

## Phase 8: User Story 6 — Savings & Investments module (P2)

**Goal**: Unified S&I module — goals list/detail, holdings-focal portfolio with heat-map toggle,
sleeve table, holding detail with FIFO lots.

**Independent Test**: Goals reconcile with `savings-overview`, holdings/sleeves with
`portfolio-overview`, heat-map cells with `benchmark-overview`; toggle + typed states render.

- [ ] T048 [US6] Implement `SavingsInvestmentsViewModel` (goal cards/detail, holdings rows with
      typed price states, allocation donut slices, sleeve rows with drift, `HeatMapModel` incl.
      S&P row + sector section, holding detail: lots/trades/dividends) in
      `Sources/FinanceWorkspaceApp/UI/SavingsInvestments/SavingsInvestmentsViewModel.swift`
- [ ] T049 [P] [US6] Write
      `Tests/FinanceWorkspaceAppTests/SavingsInvestmentsViewModelTests.swift` — typed-state
      mapping ("price unavailable", "insufficient history", "rate not set"), heat-map cell scale
      positions, sleeve drift passthrough
- [ ] T050 [US6] Build `SavingsInvestmentsView` (Overview/Goals/Portfolio sub-navigation, no
      "Categories") in
      `Sources/FinanceWorkspaceApp/UI/SavingsInvestments/SavingsInvestmentsView.swift` (FR-023)
- [ ] T051 [US6] Build `GoalsListView` (flat goal cards + progress bars) + `GoalDetailView`
      (progress history chart, `GoalFundingLink` sources, monthly contribution tracker,
      traceability) in `Sources/FinanceWorkspaceApp/UI/SavingsInvestments/GoalsListView.swift`
      and `GoalDetailView.swift` (FR-024)
- [ ] T052 [US6] Build `PortfolioView` (holdings `DataTableView` primary, standard ⇄ heat-map
      toggle with `HeatMapTableView` + sector section, allocation donut + account selector,
      sleeve table bottom) in
      `Sources/FinanceWorkspaceApp/UI/SavingsInvestments/PortfolioView.swift` (FR-025)
- [ ] T053 [US6] Build `HoldingDetailView` (security detail, FIFO tax-lot drill-down, trade
      history, dividend summary, per-row traceability) in
      `Sources/FinanceWorkspaceApp/UI/SavingsInvestments/HoldingDetailView.swift` (FR-026)
- [ ] T054 [US6] S&I checkpoint: reconcile with `savings-overview` / `portfolio-overview` /
      `benchmark-overview` (SC-004); US6 acceptance scenarios 1–5; `design-adherence` +
      `chart-styling` gates; light+dark previews

---

## Phase 9: User Story 7 — Taxes module (P2)

**Goal**: Consolidated current-tax-year view, full-width prep checklist, read-only archive.

**Independent Test**: Every section reconciles with `tax-overview`; checklist states match
`TaxPrepEngine`; archive renders read-only.

- [ ] T055 [US7] Implement `TaxesViewModel` (current-year sections; deductions with both
      standard/itemized totals + recommended flag; checklist items with state + source link;
      archive years read-only rows; estimate labeling) in
      `Sources/FinanceWorkspaceApp/UI/Taxes/TaxesViewModel.swift`
- [ ] T056 [P] [US7] Write `Tests/FinanceWorkspaceAppTests/TaxesViewModelTests.swift` — both
      deduction totals surfaced (never auto-committed), Schedule C → business-group link mapping,
      checklist state mapping, closed-year read-only flags
- [ ] T057 [US7] Build `CurrentTaxYearView` (YTD income, paid vs owed with overrides,
      effective-rate-per-account table, quarterly estimated payments paid/due, gains & income
      ST/LT + dividends + interest, deductions section incl. Schedule C business links +
      taxable-income projection; no embedded checklist; figures labeled estimates) in
      `Sources/FinanceWorkspaceApp/UI/Taxes/CurrentTaxYearView.swift` (FR-027/028)
- [ ] T058 [US7] Build `TaxPrepChecklistView` (full-width, complete/incomplete/missing, source
      link + educational content per item) + `TaxArchiveView` (closed-year selector, read-only,
      no write affordances) in `Sources/FinanceWorkspaceApp/UI/Taxes/TaxPrepChecklistView.swift`
      and `Sources/FinanceWorkspaceApp/UI/Taxes/TaxArchiveView.swift` (FR-029)
- [ ] T059 [US7] Taxes checkpoint: reconcile with `tax-overview` (SC-004); US7 acceptance
      scenarios 1–4; `design-adherence` gate; light+dark previews

---

## Phase 10: User Story 8 — Real app target & end-to-end traceability (P3)

**Goal**: The entitled app target builds in CI (OOS-1/T004 resolved) and the Milestone-5
KPI → detail → source chain is proven end-to-end.

**Independent Test**: CI green on the unsigned `xcodebuild` step; full demo script passes
against a fixture workspace with zero file writes.

- [ ] T060 [P] [US8] Create `App/project.yml` (XcodeGen: `FinanceWorkspace` macOS app target,
      bundle id `app.openfinance.FinanceWorkspace`, local package reference, DEBUG/RELEASE),
      `App/FinanceWorkspace.entitlements` (iCloud container
      `iCloud.app.openfinance.FinanceWorkspace`, CloudDocuments, sandbox), `App/Info.plist`
      (`NSUserActivityTypes`), and gitignore the generated `.xcodeproj` (contracts/app-target.md)
- [ ] T061 [US8] Add the XcodeGen generate + unsigned `xcodebuild` step to
      `.github/workflows/ci-macos.yml` after `swift test` (CODE_SIGNING_ALLOWED=NO); verify CI
      green (SC-009)
- [ ] T062 [US8] Traceability walkthrough: for each of the five modules, verify
      KPI → itemizing detail (≤2 interactions) → source inspector (1 interaction) → "Reveal in
      Finder" opens the real CSV; verify `ValueProvenanceLabel` distinguishes
      imported/derived/repaired values on the fixture (SC-003, US8 scenarios 2–3); fix gaps
- [ ] T063 [US8] Execute the Milestone-5 demo script (quickstart.md) end-to-end: fixture +
      empty-workspace launches, keyboard-only pass, dark-mode pass, re-index responsiveness,
      and the SC-005 read-only tar-compare proof; record results

**Checkpoint**: Milestone 5 gate evidence complete.

---

## Phase 11: Polish & Cross-Cutting

**Purpose**: Repo-convention closeout + quality gates.

- [ ] T064 [P] Run `design-token-sync` across DESIGN.md ⇄ `prototype/styles.css` ⇄
      `DesignSystem/`; reconcile any drift introduced during the build (+ DESIGN.md Changelog
      entries for every design decision settled this phase)
- [ ] T065 [P] Update `docs/test-plans.md` — app is now user-testable: record the Phase-5 user
      flows as testable, note the demo-script results, list still-blocked (write) flows
- [ ] T066 [P] Update `docs/out-of-scope-followups.md` — items skipped/deferred during 006
      (attributed to spec + task), e.g. edit-form surface unreachable until Phase 6, XCUITest →
      Phase 7
- [ ] T067 Update `docs/project-management.md` (close the Phase-5 `[DECIDE]`s with their
      resolutions) and `docs/product-roadmap.md` Phase-5 checkboxes; refresh the CLAUDE.md
      SPECKIT block + persistent memory (`project-state`,
      `active-spec-006-presentation-layer`) to "build complete"
- [ ] T068 Full gate pass: `swift build`, `swift test` (CI), `swiftlint --strict` (CI), and the
      quickstart.md validation sequence; fix all findings

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (P1)** → **Foundational (P2)** → **US1 (shell)** → **US2 (components)** →
  **US3–US7 (modules, parallelizable)** → **US8 (packaging + demo)** → **Polish**
- US3 (Overview) should land first among modules (first end-to-end proof; issues table feeds the
  header chip contract), then US4–US7 in any order / in parallel.
- US8 depends on all module stories (demo walks every module); T060 (App/ config) can be
  authored any time after US1 but is only *verified* at T061.

### Within Each Story

- View model (+ its tests, parallel) → views → checkpoint (CLI reconciliation +
  `design-adherence` gate + previews).

### Parallel Opportunities

- Setup: T002/T003/T004 together.
- Foundational: T006 alongside T007–T008; T009 with any later task.
- US1: T012, T016, T017, T020 parallel to neighbors as marked.
- US2: T022–T029 are all independent files — the widest parallel window.
- US3–US7: entire stories parallelizable across sessions once US2 lands; within each, the
  view-model test task is parallel to view building.
- Polish: T064/T065/T066 together.

## Implementation Strategy

**MVP first**: Phases 1–3 (T001–T021) yield a launchable, navigable shell — demo it. Then US2,
then Overview (US3) as the first live module — stop and validate against `overview-dashboard`.
Add US4–US7 incrementally (each independently reconcilable against its CLI), close with US8
packaging + the Milestone-5 demo, then Polish.

**Sizing**: 68 tasks — Setup 5, Foundational 4, US1 12, US2 10, US3 5, US4 6, US5 5, US6 7,
US7 5, US8 4, Polish 5.
