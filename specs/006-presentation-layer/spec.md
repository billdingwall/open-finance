# Feature Specification: Presentation Layer — App Shell & All Module Views

**Feature Branch**: `006-presentation-layer`
**Created**: 2026-07-01
**Status**: Draft
**Input**: User description: "Phase 5 — Presentation Layer: App Shell & All Module Views. Build the
complete SwiftUI presentation layer for the Finance Workspace macOS app, per
docs/product-roadmap.md Phase 5. The app shell ships first; then the shared UI component library
and all module views (Overview, Accounts, Budget, Savings & Investments, Taxes). All views consume
the existing Phase 3/4 domain engines via LinkingEngine; every KPI traces to detail and every
detail row traces to its source file + row (constitution principle 5). Requires the Xcode app
target + iCloud entitlement (deferred T004) and adherence to DESIGN.md tokens via the
design-adherence gate. Filter bar is deferred to V2. Charts are real Swift Charts
implementations, not placeholder SVGs."

## Overview

Phases 1–4 delivered the complete data layer: safe-write primitives, parsing/validation for the
full R6 file set, and all nine domain engines (`AccountEngine`, `BudgetEngine`, `OverviewEngine`,
`SavingsGoalEngine`, `PortfolioEngine`, `BenchmarkEngine`, `TaxEngine`, `TaxAdjustmentEngine`,
`TaxPrepEngine`) composed by `LinkingEngine`. Today those projections are only reachable through
developer CLIs — `FinanceWorkspaceApp` is a diagnostic shell and the app is not user-testable
(`docs/test-plans.md`).

This feature builds the **entire v1 presentation layer** so the app becomes a fully navigable
native macOS tool over those projections (Milestone 5: *"Fully navigable app… demoed end-to-end
against a fixture workspace"*). Scope, in build order:

1. **App shell** — window scene + macOS menu commands, the `@Observable` root app state, the
   router (navigation selection, deep links, programmatic navigation from KPI links), the left
   sidebar (expandable section groups, nested entity links, **no Overview nav row** — the sidebar
   "Finance Dashboard" header is the Overview link and the default landing), the global top header
   (issues-count chip + sync-status chip; per-view local actions on the page-title line), and the
   collapsible right detail pane (slide-over, closed by default, selection-driven).
2. **Shared component library** — KPI card, data table, pie/donut chart, sparkline, heat-map
   table, period selector, empty state, source inspector, and value-provenance label; charts are
   real Swift Charts implementations, not placeholder SVGs.
3. **Module views** — Overview (default landing), Accounts, Budget, Savings & Investments
   (including Portfolio with the heat-map toggle), and Taxes (current year, prep checklist,
   read-only archive), each connected to its live domain engine projection.

The presentation layer is **read-only in Phase 5**: it renders projections and read-only repair
*previews* (dry-run); structured write/edit/import flows and repair *apply* land in Phase 6.
Write-affordance buttons named by the wireframes (Add, Edit, Import, Delete) render **visible but
disabled** in their designed positions, so the Phase 5 layout is final and Phase 6 only enables
them.

This phase also delivers the **real app target** — the app must launch as a normal macOS
application against a real workspace folder (OOS-1: Xcode app target + iCloud entitlement; DEBUG
retains the local-folder provider).

> **Locked-decision references** (do not reopen — `docs/technical-design.md §21` and `DESIGN.md`):
> Overview is the default landing via the sidebar header (no Overview nav row); no global filter
> bar in v1 (inline period/account selection only); issues surface in the Overview table + header
> chip (no standalone Issues view, V2); Notes viewer V2; detail pane is closed by default and
> opens on main-panel selection; single brand accent, semantic tokens only; account-group screens
> have no sub-tabs; goals render as a flat list (no active/archived grouping); the benchmark heat
> map is a holdings-table view toggle, not a standalone screen.

## Clarifications

### Session 2026-07-02

- Q: How long do in-module selections (period, account, tax year) persist? → A: **Session-only** —
  selections persist while navigating within a session and reset to current/all on relaunch; state
  restoration reopens only the last module + entity.
- Q: How does the router encode navigation state for deep links / state restoration? → A:
  **`NSUserActivity` user-info dictionary** (domain + entity selection); no custom URL scheme in
  v1.
- Q: How do Phase 5 views render write actions (Add/Edit/Import/Delete/New group) whose flows
  arrive in Phase 6? → A: **Visible but disabled** in their designed positions — layout is final
  in Phase 5; Phase 6 enables them. They are never hidden and never open placeholder forms.
- Q: How is the Xcode app target + iCloud entitlement handled on the CLT-only dev box? → A: **In
  scope, CI-gated** — the Xcode project + entitlement are authored in-repo as the last story
  (US8) and built/verified in macOS CI (the Milestone 5 gate); all views remain SwiftPM-buildable
  locally throughout.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - App shell, navigation & detail pane (Priority: P1)

The user launches the app and lands on the Overview dashboard. A three-column
`NavigationSplitView` shell presents: a left sidebar with a "Finance Dashboard" header (the
Overview link) and expandable section groups (Accounts → account groups → accounts; Budget;
Savings & Investments → goals/portfolio; Taxes) with active-selection highlight and keyboard
navigation; a main content column with a global top header (issues-count chip immediately left of
the sync-status chip) and per-view local actions on the page-title line; and a collapsible right
detail pane that slides over when a row or KPI detail is selected and can be closed/toggled
(⌘⌥I "Toggle Inspector"). macOS menu commands (§17 set) are present with keyboard shortcuts.

**Why this priority**: Every module view mounts inside the shell; `AppState` and `AppRouter` are
the roadmap's critical dependency — nothing else can be connected until they are stable.

**Independent Test**: Launch the app against a fixture workspace; verify the Overview landing,
sidebar expansion/selection/keyboard navigation, header chips reflecting real issue/sync state,
detail-pane open/close, and each menu command either performing its action or being disabled —
with placeholder module content and no module views built yet.

**Acceptance Scenarios**:

1. **Given** a provisioned workspace, **When** the app launches, **Then** the Overview dashboard
   is the selected content (no Overview row exists in the sidebar; the sidebar header navigates to
   it) and the window respects the minimum window size.
2. **Given** the sidebar, **When** the user expands a section group and selects a nested entity
   (an account group, account, or goal), **Then** the main column shows that entity's view, the
   selection is highlighted, and the same navigation is reachable by keyboard alone.
3. **Given** validation issues and sync activity, **When** the shell renders, **Then** the header
   shows an issues-count chip (count from the aggregated validation issues) immediately left of
   the sync-status chip, and both update when the underlying state changes.
4. **Given** a selected row in any main panel, **When** the selection is made, **Then** the right
   detail pane slides over (closed by default before that) showing the surface appropriate to the
   selection, and closes via its close button or the Toggle Inspector command.
5. **Given** a KPI link or programmatic navigation request (e.g. an Overview card tap), **When**
   the router handles it, **Then** the sidebar selection, breadcrumb, and content column all
   update consistently, and the navigation state can be encoded/restored (deep-link round trip).
6. **Given** an empty sidebar group (e.g. no savings goals), **When** rendered, **Then** the group
   shows its designed empty state rather than disappearing or crashing.

---

### User Story 2 - Shared component library (Priority: P1)

The system provides the reusable component set every module composes: KPI card (overline label,
tabular value, delta, whole-card tap target), sortable data table (sticky header, right-aligned
tabular numerals, row selection, per-row traceability target), pie/donut chart, sparkline,
heat-map table (period columns, color-scaled cells, benchmark comparison row), period selector
(month/quarter/year with previous/next), empty state, source inspector (file path, row number,
last-modified, raw field values, "Open in Finder" / "Open in Editor"), and value-provenance label
(imported / derived / repaired / user-edited).

**Why this priority**: All five module views are compositions of these components; building them
once against `DESIGN.md` contracts prevents per-module drift.

**Independent Test**: Render each component in a preview/harness with representative fixture data
and verify layout, `DESIGN.md` token usage, sorting/selection behavior, chart rendering (Swift
Charts), and the empty/degenerate states — without any module view existing.

**Acceptance Scenarios**:

1. **Given** a KPI card with a positive/negative/flat delta, **When** rendered, **Then** the delta
   uses the pos/neg semantic colors, the value uses tabular numerals, and tapping anywhere on the
   card fires its navigation action.
2. **Given** a data table with numeric and text columns, **When** the user sorts by a column and
   selects a row, **Then** ordering is correct and stable, numerals are right-aligned and tabular,
   and the row's traceability target opens the source inspector for that record.
3. **Given** the chart components, **When** rendered with fixture series, **Then** pie, sparkline,
   and heat map are real Swift Charts implementations following the chart styling rules
   (single-accent series, tabular axis labels, pos/neg heat-map cell scale).
4. **Given** a record with source metadata, **When** the source inspector opens, **Then** it shows
   file path, row number, last-modified date, and raw field values, and "Open in Finder"/"Open in
   Editor" reveal the actual file.
5. **Given** a component with no data, **When** rendered, **Then** the configurable empty state
   (glyph, title, one-line message, optional CTA) appears instead of a blank or broken layout.

---

### User Story 3 - Overview module (Priority: P1)

The user lands on the Overview dashboard: a 5-KPI card grid (Budget, Savings, Investments, Taxes,
Business — live values from `OverviewEngine`, no filters), a month-over-month panel, and an
inline validation-issues table grouped by severity with a repairable badge and a read-only
"Preview Repair" action per repairable issue. Each KPI card navigates to its module on tap.

**Why this priority**: Overview is the default landing and the first end-to-end proof that the
shell + components + a live engine compose; it is also the v1 home of issue visibility.

**Independent Test**: Launch against a fixture workspace with known engine outputs and seeded
validation issues; verify the five cards match `overview-dashboard` CLI values, card taps navigate,
the MoM panel matches the engine's gap-skipping 6-month series, and Preview Repair shows the
dry-run diff without writing.

**Acceptance Scenarios**:

1. **Given** the fixture workspace, **When** Overview renders, **Then** all five KPI cards show
   live values that reconcile with the `OverviewEngine` projection (and the CLI output), including
   typed states such as "rate not set" where the engine reports them.
2. **Given** a KPI card, **When** tapped, **Then** the router navigates to that module's main view.
3. **Given** validation issues, **When** the issues table renders, **Then** issues are grouped by
   severity, repairable issues carry a badge, and the header issues-chip count equals the table's
   issue count.
4. **Given** a repairable issue, **When** the user invokes Preview Repair, **Then** a read-only
   dry-run preview (issue, proposed fix, affected file/rows) appears in the detail pane and **no
   file is modified**; the apply action is deferred to Phase 6 (disabled or absent).

---

### User Story 4 - Accounts module (Priority: P2)

The user browses accounts three levels deep: (1) an all-accounts card grid with an aggregate
header, grouped by account group; (2) an account-group screen with individual-account cards above
the group's inline transaction ledger (no sub-tabs) — for business groups, a P&L summary and
monthly net-income chart with the ledger inline below, category budgets, and linked notes
references; (3) a per-account screen with the transactions table, a monthly gross vs
expenses/tax chart, and YTD net income, plus the account's rules and estimates panel. Account
screens surface both assets and liabilities (net-worth view). Multi-entry transactions (a
paycheck's gross → withholdings → net; a mortgage split) display as one grouped unit, not flat
rows.

**Why this priority**: Accounts is the master registry every other domain references; its screens
are the primary traceability surface for ledger data. It depends only on US1–US3 patterns.

**Independent Test**: Navigate fixture data from the card grid → a business group screen → a
per-account screen; verify aggregates, P&L, charts, ledger contents, grouped multi-entry display,
and row-level source traceability against `accounts-overview` CLI values.

**Acceptance Scenarios**:

1. **Given** the fixture registry, **When** the accounts grid renders, **Then** every account
   appears grouped by account group with an aggregate header, assets and liabilities both
   surfaced, and card taps navigate to the per-account screen.
2. **Given** a business account group, **When** its screen renders, **Then** it shows the P&L
   summary and monthly net-income chart with the ledger inline below (no sub-tabs), category
   budgets, and linked-notes references, all reconciling with `AccountEngine`.
3. **Given** a per-account screen, **When** rendered, **Then** the transactions table, monthly
   gross vs expenses/tax chart, YTD net income, and the rules/estimates panel match the engine
   projection; Import/Add/Edit/Delete affordances render visible but disabled (Phase 6 enables).
4. **Given** a multi-entry transaction (paycheck or split payment), **When** the ledger renders,
   **Then** its legs display as one grouped unit with the group expandable to its legs.
5. **Given** any ledger row, **When** its traceability target is invoked, **Then** the source
   inspector shows the row's source file and row number.

---

### User Story 5 - Budget module (Priority: P2)

The user reviews the budget: an overview with the category pie chart, Spend Mix and Spending
Variance panels side-by-side at 50/50, a category table (plan / actual / variance / 3-month
trailing average), and a period selector; tapping a category opens a category-filtered
transaction view. A history view shows month-over-month variance across a period range, and a
categories view lists categories/subcategories (management forms deferred to Phase 6).

**Why this priority**: Budget is the highest-frequency user surface and exercises the pie chart,
period selector, and drill-down patterns; it depends on shared components.

**Independent Test**: Render against fixture budget data; verify plan/actual/variance/trailing
averages against `budget-overview` CLI values for multiple selected periods, and confirm the
category drill-down filter and back-navigation.

**Acceptance Scenarios**:

1. **Given** the fixture budget, **When** the budget overview renders for the current month,
   **Then** the pie chart, 50/50 Spend Mix / Spending Variance panels, and category table all
   reconcile with `BudgetEngine` (including partial-aware trailing averages).
2. **Given** the period selector, **When** the user steps to a previous month, **Then** all panels
   and the table recompute for that period.
3. **Given** a category row, **When** tapped, **Then** a transaction view filtered to that
   category and period opens, with each row traceable to source.
4. **Given** the history view, **When** a period range is selected, **Then** month-over-month
   variance renders for that range; **Given** the categories view, **Then** categories and
   subcategories list correctly with create/edit affordances visible but disabled (Phase 6).

---

### User Story 6 - Savings & Investments module (Priority: P2)

The user opens the unified Savings & Investments module with Overview, Goals, and Portfolio
sub-navigation. Goals: a flat list of goal cards with progress bars (no active/archived
grouping), tapping a goal opens its detail (progress history chart, funding-source links, monthly
contribution tracker, source traceability). Portfolio: the holdings table is the primary surface
with a standard ⇄ heat-map view toggle (heat map: 8 periods × accounts with an S&P 500 comparison
row and a sector performance section); an allocation donut and account selector support it; the
sleeve table sits at the bottom (target vs actual weights, contribution target, drift indicator).
Tapping a holding opens the security detail with tax-lot drill-down, trade history, and dividend
summary.

**Why this priority**: The richest visual module (heat map, donut, drift) — it proves the chart
components against the Phase 4 engines but depends on nothing beyond them and US2.

**Independent Test**: Render against fixture portfolio/goal data; verify goal progress against
`savings-overview`, holdings/sleeve values against `portfolio-overview`, and heat-map cells
against `benchmark-overview`; toggle standard ⇄ heat-map and drill into a holding's tax lots.

**Acceptance Scenarios**:

1. **Given** fixture goals, **When** the goals list renders, **Then** every non-archived goal
   shows as a card with progress bar (flat list) and its detail view reconciles with
   `SavingsGoalEngine` (progress, gap, months-to-goal, funding links).
2. **Given** fixture holdings, **When** the portfolio view renders, **Then** the holdings table
   shows current value, cost basis, and unrealized gain/loss reconciling with `PortfolioEngine`,
   with typed states ("price unavailable") rendered as such.
3. **Given** the view toggle, **When** switched to heat map, **Then** the 8-period × account grid
   renders with color-scaled cells, the S&P 500 comparison row, and the sector performance
   section, matching `BenchmarkEngine` (including "insufficient history" cells).
4. **Given** the sleeve table, **When** rendered, **Then** each sleeve shows target vs actual
   weight and a drift indicator matching the engine.
5. **Given** a holding, **When** tapped, **Then** its detail shows FIFO tax lots, trade history,
   and dividend summary, each row traceable to its source file + row.

---

### User Story 7 - Taxes module (Priority: P2)

The user opens the Taxes module: a Current Tax Year view with YTD taxable income, taxes paid vs
owed, an effective-rate-per-account table, an estimated-payments section (quarterly schedule with
paid/due status), a gains & income section (realized gain/loss split short/long-term, dividends,
interest), and a deductions section (standard vs itemized with the recommended choice flagged,
above-the-line, Schedule A, Schedule C linked to business groups, taxable-income projection) —
with no prep checklist embedded. A full-width Tax Prep Checklist view shows
complete/incomplete/missing item states with source links and educational content per step. A Tax
Archive view lists closed prior years read-only.

**Why this priority**: Completes the module set; depends on the Phase 4 tax engines and the table
components but no other module.

**Independent Test**: Render against the fixture tax year; verify every section against
`tax-overview` CLI values, checklist states against `TaxPrepEngine`, and that a closed year's
archive renders read-only.

**Acceptance Scenarios**:

1. **Given** the fixture tax year, **When** the current-year view renders, **Then** YTD income,
   taxes paid vs owed (computed projection with stored overrides), the per-account effective-rate
   table, quarterly estimated payments with paid/due status, and the gains & income section all
   reconcile with the tax engines.
2. **Given** the deductions section, **When** rendered, **Then** standard vs itemized totals both
   display with the greater flagged as recommended (no auto-commit), Schedule C rows link to
   their owning business account-group, and the taxable-income projection matches the engine.
3. **Given** the prep checklist view, **When** rendered, **Then** each item shows its
   complete/incomplete/missing state with a source link and per-step educational content.
4. **Given** a closed year archive, **When** opened, **Then** archived adjustments and payments
   render clearly marked read-only with no write affordances.

---

### User Story 8 - Real app target & end-to-end traceability (Priority: P3)

The app ships as a real macOS application (Xcode app target; iCloud ubiquity-container entitlement
resolving deferred T004/OOS-1; DEBUG builds retain the local-folder provider) and the Milestone 5
demo passes: from any Overview KPI the user can drill to the module, from any detail row open the
source inspector, and from the inspector reveal the actual CSV row's file — the full
KPI → detail → source chain, live, against a fixture workspace.

**Why this priority**: Packaging and the cross-cutting traceability proof integrate everything
above; they are the Milestone 5 gate but block nothing during module development.

**Independent Test**: Run the packaged app end-to-end against a freshly bootstrapped +
fixture-populated workspace and walk each module's KPI → detail → source chain; confirm the
iCloud-entitled release configuration builds and the DEBUG local-folder path still works.

**Acceptance Scenarios**:

1. **Given** the app target, **When** built and launched (not the diagnostic shell), **Then** it
   opens the workspace via the configured provider (iCloud container in release; local folder in
   DEBUG) and reaches the Overview landing.
2. **Given** any module KPI or summary value, **When** the user drills down, **Then** a detail
   surface itemizing that value appears, and every detail row's inspector resolves to a real
   source file + row that "Open in Finder" reveals.
3. **Given** derived, imported, and repaired values in the fixture, **When** rendered, **Then**
   the value-provenance label distinguishes them correctly.
4. **Given** the full demo script (`docs/test-plans.md` user flows), **When** executed against the
   fixture workspace, **Then** every v1 flow that Phase 5 unblocks completes without a crash and
   without writing to the workspace.

### Edge Cases

- **Empty workspace**: a freshly bootstrapped workspace with no fixture data renders designed
  empty states on every surface (no blank panels, no crashes); the "add your first…" CTAs may be
  disabled until Phase 6.
- **Typed engine states**: "price unavailable", "insufficient history", "rate not set",
  months-to-goal "n/a" render as their designed states — never as zero, blank, or a crash.
- **Partially-invalid files**: parse/validation errors surface in the issues chip + Overview
  table while unaffected views keep rendering from the valid subset.
- **Narrow window**: at the minimum window size, columns collapse per the layout spec — content
  is never clipped into unusability.
- **Detail pane vs navigation**: navigating to another view while the pane is open closes or
  re-scopes the pane (never a stale inspector for an off-screen record).
- **Missing source file**: an inspector whose source file was moved/deleted since indexing shows
  an explicit missing-source state; "Open in Finder" is disabled rather than failing silently.
- **Keyboard-only session**: sidebar navigation, row selection, period stepping, and the Toggle
  Inspector command are all operable without a pointer.
- **Long-running index**: while indexing/re-indexing, the sync-status chip shows progress state
  and stale views refresh when the new projection lands (no partially-mixed old/new data).
- **Dark mode**: every surface, chart, and status color follows the semantic dark-mode tokens
  (no hardcoded light-only values).

## Requirements *(mandatory)*

### Functional Requirements

**App shell**

- **FR-001**: The app MUST present a three-column `NavigationSplitView` shell (sidebar / content /
  selection-driven right detail pane) honoring the `DESIGN.md` layout tokens (sidebar width,
  detail-pane width range, minimum window size, column-collapse behavior).
- **FR-002**: A single `@Observable` root state object MUST own workspace state, indexing state,
  active module selection, navigation path, and detail-pane state; **Overview MUST be the default
  selection on launch**.
- **FR-003**: A router MUST manage `NavigationSplitView` selection, encode/decode deep-link state
  (domain + group/account/goal selection) as an `NSUserActivity` user-info dictionary for state
  restoration (no custom URL scheme in v1), and handle programmatic navigation from KPI links;
  the sidebar header ("Finance Dashboard") navigates to Overview.
- **FR-004**: The left sidebar MUST provide expandable section groups with nested
  account-group/account/goal/portfolio links, active-selection highlight, keyboard navigation,
  designed empty-group states, and **no Overview nav row**; the Accounts nested group is labelled
  "Account groups" with a "New group" affordance (visible but disabled until Phase 6).
- **FR-005**: The global top header MUST show an issues-count chip (aggregated validation issues)
  immediately left of the sync-status chip, both live; per-view local actions MUST render on the
  page-title line (right-aligned), with a breadcrumb above the page title where the view is
  nested.
- **FR-006**: The right detail pane MUST be a collapsible slide-over, **closed by default**,
  opening on main-panel selection, supporting these surfaces: inspector, source file preview,
  source row detail, validation issue detail, repair preview, and edit form (form surface present;
  commit path Phase 6); edit/delete actions sit at the bottom for right-panel objects.
- **FR-007**: The app MUST provide the macOS menu command set from `docs/technical-design.md §17`
  (New/Open/Reindex/Validate Workspace, Repair Selected Issue, Open Source File, Reveal in Finder,
  Export Current View, Toggle Inspector, Open Backup Folder) with non-conflicting keyboard
  shortcuts; commands whose flows are Phase 6 (Repair apply, Export) MUST be present but disabled.

**Shared component library**

- **FR-008**: The system MUST provide a reusable KPI card (overline title, tabular primary value,
  secondary value, pos/neg/flat trend indicator, whole-card tap target → navigation action).
- **FR-009**: The system MUST provide a sortable data table with column definitions, sticky
  uppercase header, dense rows per the row-height token, right-aligned tabular numerals, row
  selection, and a per-row traceability target.
- **FR-010**: The system MUST provide pie/donut, sparkline, and heat-map-table chart components
  implemented on **Swift Charts** (not placeholder SVGs or hand-drawn shapes), following the
  chart styling rules: single-accent series, tabular axis labels, pos/neg heat-map cell scale,
  benchmark comparison row support.
- **FR-011**: The system MUST provide a period selector (month/quarter/year with previous/next),
  a configurable empty state (glyph, title, one-line message, optional CTA), and a loading
  skeleton for projection-pending surfaces.
- **FR-012**: The system MUST provide a source inspector showing file path, row number,
  last-modified date, and raw field values for a selected record, with working "Open in Finder"
  and "Open in Editor" actions, and an explicit missing-source state.
- **FR-013**: The system MUST provide an inline value-provenance label distinguishing imported /
  derived / repaired / user-edited values.
- **FR-014**: A global filter bar MUST NOT be built (deferred to V2); filtering is limited to the
  inline period/account/tax-year selectors named per module. Selector state is **session-scoped**:
  it persists while navigating within a session and resets to current/all on relaunch (only the
  last module + entity selection is restored via deep-link state).

**Overview module**

- **FR-015**: The Overview view MUST render the 5-KPI card grid from the live `OverviewEngine`
  projection (no filters), a month-over-month panel from the gap-skipping 6-month series, and an
  inline issues table; each KPI card MUST navigate to its module on tap.
- **FR-016**: The issues table MUST group validation issues by severity, badge repairable issues,
  and offer a **read-only** "Preview Repair" per repairable issue that shows the dry-run
  diff/description in the detail pane without writing; repair apply is out of scope (Phase 6).

**Accounts module**

- **FR-017**: The Accounts view MUST render all accounts as cards grouped by account group with an
  aggregate header surfacing assets and liabilities (net-worth view); card taps navigate to the
  per-account screen; group headers navigate to the account-group screen.
- **FR-018**: The account-group screen MUST show individual-account cards above the group's inline
  transaction ledger with **no sub-tabs**; for `group_type = business` groups it MUST add the P&L
  summary, monthly net-income chart (ledger inline below), category budgets, and linked-notes
  references, reconciling with `AccountEngine`.
- **FR-019**: The per-account screen MUST show the transactions table, monthly gross vs
  expenses/tax chart, YTD net income, and the account's rules-and-estimates panel; Import / Add /
  Edit / Delete affordances render **visible but disabled** in the designed positions (edit in
  local actions, delete inside the edit flow) — never hidden, never placeholder forms.
- **FR-020**: Ledgers MUST display multi-entry transactions (paycheck gross → withholdings → net;
  split principal/interest payments) as one grouped, expandable unit rather than flat rows.

**Budget module**

- **FR-021**: The budget overview MUST render the category pie chart, Spend Mix and Spending
  Variance panels at 50/50, and a category table (plan / actual / variance / 3-month trailing
  average) for the selected period, reconciling with `BudgetEngine`; tapping a category MUST open
  a category+period-filtered transaction view.
- **FR-022**: The budget history view MUST render month-over-month variance over a selectable
  period range; the categories view MUST list categories and subcategories with create/edit
  affordances visible but disabled (enabled in Phase 6).

**Savings & Investments module**

- **FR-023**: The module MUST present Overview, Goals, and Portfolio sub-navigation (no
  "Categories" — removed R3) organized by portfolio.
- **FR-024**: The goals list MUST render a flat list of goal cards with progress bars (no
  active/archived grouping; archived goals are already excluded by the engine); goal detail MUST
  show the progress history chart, funding-source links, and monthly contribution tracker with
  source traceability, reconciling with `SavingsGoalEngine`.
- **FR-025**: The portfolio view MUST make the holdings table the primary surface with a standard
  ⇄ heat-map toggle — the heat map rendering 8 periods × accounts with color-scaled cells, an
  S&P 500 comparison row, and a sector performance section from `BenchmarkEngine` — supported by
  an allocation donut and account selector, with the sleeve table (target vs actual weight,
  contribution target, drift indicator) at the bottom from `PortfolioEngine`.
- **FR-026**: The holding detail MUST show security detail, FIFO tax-lot drill-down, trade
  history, and dividend summary, every row traceable to its source file + row.

**Taxes module**

- **FR-027**: The current-tax-year view MUST render, in one consolidated view with **no embedded
  prep checklist**: YTD taxable income, taxes paid vs owed (computed projection, stored overrides
  honored), the effective-rate-per-account table, the estimated-payments section (quarterly
  schedule, paid/due status), and the gains & income section (realized gain/loss split
  short-/long-term, dividends, interest), reconciling with `TaxEngine`/`TaxAdjustmentEngine`.
- **FR-028**: The deductions section MUST show standard vs itemized with the greater flagged as
  recommended (never auto-committed), above-the-line items, Schedule A, Schedule C rows linked to
  their owning business account-groups, and the taxable-income projection.
- **FR-029**: The tax-prep checklist view MUST render full-width with complete / incomplete /
  missing item states from `TaxPrepEngine`, a source link per item, and educational content per
  step; the tax archive view MUST list closed years and render archived adjustments/payments
  read-only with no write affordances.

**Cross-cutting**

- **FR-030**: Every KPI and summary value MUST link to a detail surface itemizing it, and every
  detail row MUST expose its source file + row via the source inspector (constitution P-V), across
  all modules.
- **FR-031**: All views MUST consume domain-engine projections via `LinkingEngine`/the engines'
  public APIs — no view computes domain figures, re-parses files, or reaches around the read
  model; typed engine states render as their designed representations, never zero-filled.
- **FR-032**: The presentation layer MUST NOT write to the workspace: Phase 5 performs no file
  mutation (repair previews are dry-run only; write-affordance buttons are visible but disabled).
- **FR-033**: All UI MUST use `DESIGN.md` semantic tokens (colors, type scale, spacing, radius,
  materials) via the SwiftUI token layer — no improvised values — and MUST support light and dark
  mode; each view change clears the `design-adherence` gate during implementation.
- **FR-034**: The app MUST be fully keyboard-navigable (sidebar, tables, period selectors, detail
  pane toggle) and use native macOS patterns (system materials, SF Pro, standard focus behavior)
  per constitution P-III.
- **FR-035**: The app MUST ship a real macOS app target with the iCloud ubiquity-container
  entitlement (resolving deferred T004 / OOS-1) for release configuration, while DEBUG builds
  retain the local-folder workspace provider; the diagnostic shell behavior is replaced by the
  real shell. The Xcode project + entitlement are authored in-repo and **verified in macOS CI**
  (the CLT-only dev box never blocks: all views remain buildable via SwiftPM locally, and the
  app-target story lands last).
- **FR-036**: While indexing or re-indexing, the UI MUST stay responsive, show progress via the
  sync-status chip, and swap to refreshed projections atomically (no mixed stale/fresh view
  state).

### Key Entities *(include if feature involves data)*

- **AppState** — the observable root: workspace + indexing state, active module, navigation path,
  detail-pane state; the single source of UI truth.
- **AppRouter / Route** — the navigation model: module + entity selection, deep-link
  encode/decode, programmatic navigation requests (KPI links).
- **DetailPaneSurface** — the enumerated right-pane content types: inspector, source file
  preview, source row detail, validation issue detail, repair preview, edit form.
- **SourceReference presentation** — the traceability payload each row carries to the inspector:
  file path, row number, last-modified, raw fields, provenance class.
- **Component contracts** — KPI card, data table (column defs + sort + selection), chart series
  (pie/sparkline/heat-map cell model), period selection, empty-state config: the shared vocabulary
  every module composes.
- **Module view models** — per-module presentation adapters mapping engine projections
  (`OverviewSummaryCard`, account/budget projections, `HoldingsProjection`, heat-map model,
  `TaxDeductionSummary`, `TaxPrepSummary`, archive years) into the component contracts.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Launching the packaged app against a 12-month fixture workspace lands on Overview
  with all five KPI cards live, and 100% of their values reconcile with the corresponding CLI
  projections (`overview-dashboard` et al.).
- **SC-002**: Every v1 module view (Overview, Accounts ×3 levels, Budget ×3 views, S&I with goals
  + portfolio + heat-map toggle + holding detail, Taxes ×3 views) is reachable by sidebar, by
  keyboard alone, and by KPI drill-down — the Milestone 5 demo script completes end-to-end
  without a crash.
- **SC-003**: From any KPI a user reaches an itemizing detail in ≤ 2 interactions, and from any
  detail row reaches the source inspector in 1 interaction, with "Open in Finder" revealing the
  actual file — verified across all five modules (constitution P-V, 100% of sampled rows).
- **SC-004**: Rendered figures match engine projections exactly (same rounding/typed states) on
  the fixture workspace for every module — zero view-computed domain values found in review.
- **SC-005**: A full app session (launch → browse all modules → previews → quit) performs **zero
  workspace file writes** (byte-identical workspace before/after, backup folder unchanged).
- **SC-006**: All typed engine states ("price unavailable", "insufficient history", "rate not
  set", "n/a") and all empty-workspace surfaces render designed states — no blank panels, zeros,
  or crashes in a state-matrix walkthrough.
- **SC-007**: Every color, font, spacing, and radius in the shipped views resolves to a
  `DESIGN.md` token (design-token-sync audit passes; light and dark mode both render correctly
  on all views).
- **SC-008**: All charts are Swift Charts implementations; zero placeholder/static chart assets
  remain in the app target.
- **SC-009**: The release configuration builds with the iCloud container entitlement and DEBUG
  runs against a local folder; `swift build` stays green and `swiftlint --strict` + `swift test`
  pass in macOS CI.
- **SC-010**: With a realistic fixture (12 months, multiple accounts/groups), initial projection
  render after launch and view-to-view navigation feel immediate (no visible stalls; loading
  skeletons cover any projection-pending gap), and the UI remains interactive during a full
  re-index.

## Assumptions

- **Read-only phase** (clarified 2026-07-02): All write/edit/import/delete flows, repair *apply*,
  and export execution are Phase 6; Phase 5 renders their affordances **visible but disabled** in
  final positions, and the detail pane's edit-form *surface* type exists without a commit path
  (unreachable until Phase 6 enables the actions). The multi-entry transaction *editor* commit
  path is likewise Phase 6; Phase 5 delivers the grouped display.
- **Filter/persistence** (clarified 2026-07-02): selections (budget period, portfolio account,
  tax year) default to "current/all", persist for the session while navigating, and reset on
  relaunch except the last selected module + entity, which the deep-link restoration preserves.
  No filters on Overview.
- **Traceability interaction default**: KPI cards navigate to the module main view (per roadmap);
  drill-down filtering happens inside the module. Selecting a row opens the detail pane
  (selection-driven, per `DESIGN.md`); Toggle Inspector (⌘⌥I) closes/reopens it.
- **Deep-link encoding** (clarified 2026-07-02): navigation state is encoded in an
  `NSUserActivity` user-info dictionary; no custom URL scheme in v1 (one can be added later
  without rework if external linking is ever needed).
- **Menu shortcuts**: the §17 command list is authoritative; exact shortcut assignments are a
  plan-time design decision checked against system shortcuts.
- **Design decisions flow through `DESIGN.md`**: the Phase 5 design `[DECIDE]`s (sidebar states,
  context header, pane surfaces, component specs, wireframes) are settled in `DESIGN.md` + the
  prototype as part of implementation, each with a Changelog entry, gated by `design-adherence` —
  this spec does not restate visual values.
- **Prototype is the reference**: `prototype/` HTML/CSS is the layout/flow reference; where it and
  the roadmap conflict, the later refinement round wins (e.g. no sub-tabs, flat goal list,
  holdings-focal portfolio).
- **Toolchain** (clarified 2026-07-02): building/running the app target and `swift test` require
  full Xcode and are verified in macOS CI; the CLT-only dev box builds the package via SwiftPM.
  The Xcode-project/entitlement work is staged as the final story (US8), CI-gated, so local
  development is never blocked. SwiftUI previews/harnesses are used where the toolchain allows.
- **Engines are stable**: Phase 3/4 engines (merged) provide all data; any engine gap discovered
  is a followup (`docs/out-of-scope-followups.md`), not an in-view computation.
- **V2 exclusions hold**: Notes viewer, standalone Issues view, Files explorer, budget
  rules/automation, sync, multi-workspace, AI analysis remain out (constitution / roadmap).

## Dependencies

- **Phase 1–2** — workspace provisioning, indexing, parsing/validation, `SettingsStore`,
  safe-write primitives (used by nothing in this phase — presentation is read-only). Merged.
- **Phase 3** — `AccountEngine`, `BudgetEngine`, `LinkingEngine`, `OverviewEngine`. Merged
  (`004-domain-accounts-budget-overview`).
- **Phase 4** — `SavingsGoalEngine`, `PortfolioEngine`, `BenchmarkEngine`, `TaxEngine`,
  `TaxAdjustmentEngine`, `TaxPrepEngine`, live Overview cards, fixtures (`fixture-generate`).
  Merged (PR #19; `005-savings-investments-tax`).
- **`DESIGN.md` + skills** — the design gate (`design-adherence`), `swiftui-view-scaffold`,
  `design-token-sync`, `chart-styling` govern all view work.
- **Build order** — US1 (shell: `AppState`/`AppRouter` stable) strictly before module connection;
  US2 (components) before US3–US7; US3 (Overview) first module; US4–US7 parallelizable; US8
  (packaging + Milestone 5 demo) last.
- **OOS backlog resolved here** — OOS-1 (iCloud entitlement + app target), OOS-3 (validation/
  repair UI design — preview only), OOS-6 (Phase 3 module UI design).

## Out of Scope

- All workspace writes: structured add/edit/delete forms, CSV import flow, repair **apply**,
  export execution, backup management UI (→ Phase 6). Phase 5 ships previews and disabled
  affordances only.
- Performance tuning targets, accessibility (VoiceOver/WCAG) and dark-mode **audits**, final
  iconography, onboarding polish (→ Phase 7; Phase 5 builds dark-mode-correct, keyboard-navigable
  views but the formal audits come later).
- Notes viewer, standalone Issues view, Files explorer, budget rules/automation, bank/brokerage
  sync, multi-workspace, AI analysis, global filter bar (→ V2).
- Dedicated sleeves / benchmark / deductions standalone screens (those surfaces live within
  existing screens) (→ V2).
- Any change to domain-engine behavior, schemas, or validation rules — presentation only.
