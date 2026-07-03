# Contract — Module Views ⇄ Engine Projections

Every view consumes its view model's mapping of the current `WorkspaceProjections` snapshot; no
view touches Parsing/Platform or computes finance figures (FR-031). Rendered values must
reconcile with the corresponding CLI output on the same fixture (SC-001/004).

## Overview (`UI/Overview/`) — FR-015/016

- `OverviewView`: 5 `KPICardView`s from `OverviewDashboard.cards` (incl. `RateState` typed
  rendering), MoM sparkline panel (gap-skipping 6-mo series), `OverviewIssuesTableView` inline.
- `OverviewIssuesTableView`: severity-grouped issues, repairable badge, "Preview Repair" →
  `RepairService` **dry-run** → `.repairPreview` pane surface. No apply.
- CLI reconciliation: `overview-dashboard`.

## Accounts (`UI/Accounts/`) — FR-017–020

- `AccountsView`: aggregate header (assets + liabilities), group sections, account cards →
  `.account`; group header → `.accountGroup`.
- `AccountGroupDetailView`: account cards above inline `LedgerTableView` (no sub-tabs); business
  groups add P&L summary panel, monthly net-income `BarChartView`, category budgets, linked-notes
  references (rendered as references only — no Notes viewer).
- `AccountDetailView`: transactions `LedgerTableView`, monthly gross vs expenses/tax chart, YTD
  net income, rules & estimates panel; Import/Add/Edit/Delete visible-disabled.
- CLI reconciliation: `accounts-overview`.

## Budget (`UI/Budget/`) — FR-021/022

- `BudgetOverviewView`: `PieChartView`, Spend Mix + Spending Variance panels at 50/50, category
  `DataTableView` (plan/actual/variance/3-mo trailing), `PeriodSelectorView`; category tap →
  filtered transaction list (in-module), rows traceable.
- `BudgetHistoryView`: MoM variance over a period range. `BudgetCategoriesView`: category/
  subcategory list, create/edit visible-disabled.
- CLI reconciliation: `budget-overview` (per selected period).

## Savings & Investments (`UI/SavingsInvestments/`) — FR-023–026

- `SavingsInvestmentsView`: Overview / Goals / Portfolio sub-navigation (no "Categories").
- `GoalsListView`: flat goal cards + progress bars; `GoalDetailView`: progress history chart,
  funding-source links (`GoalFundingLink`), monthly contribution tracker, traceability.
- `PortfolioView`: holdings `DataTableView` primary; standard ⇄ heat-map toggle
  (`HeatMapTableView`: 8 × accounts, S&P row, sector section); allocation donut + account
  selector supporting; sleeve table bottom (target/actual/drift). Typed "price unavailable" /
  "insufficient history" states rendered.
- `HoldingDetailView`: security detail, FIFO tax-lot drill-down, trade history, dividend summary.
- CLI reconciliation: `savings-overview`, `portfolio-overview`, `benchmark-overview`.

## Taxes (`UI/Taxes/`) — FR-027–029

- `CurrentTaxYearView`: YTD income, paid vs owed (computed + overrides), effective-rate-per-account
  table, estimated payments (quarterly, paid/due), gains & income (ST/LT split, dividends,
  interest), deductions section (both standard/itemized totals + recommended flag, above-the-line,
  Schedule A, Schedule C → business-group links, taxable-income projection). No embedded checklist.
  All figures labeled estimates (V1 scope boundary).
- `TaxPrepChecklistView`: full-width; complete/incomplete/missing states, source link +
  educational content per item.
- `TaxArchiveView`: closed-year selector; archived adjustments/payments read-only, no write
  affordances.
- CLI reconciliation: `tax-overview`.

## Cross-cutting acceptance hooks

- Every table row carries a `SourceRef` → `SourceInspectorView` (FR-030, SC-003).
- Every module renders `EmptyStateView` for data-less surfaces and `LoadingSkeletonView` during
  first index (edge cases).
- Each view ships light/dark `#Preview`s and passes the `design-adherence` gate before merge
  (FR-033).
