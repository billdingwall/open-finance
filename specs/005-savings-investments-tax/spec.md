# Feature Specification: Domain Layer II — Savings, Investments & Tax

**Feature Branch**: `005-savings-investments-tax`
**Created**: 2026-06-30
**Status**: Draft
**Input**: User description: "Phase 4 — Domain Layer II: Savings, Investments & Tax. Build the remaining domain engine groups on top of the Phase 3 master account registry, per docs/product-roadmap.md Phase 4 (lines 430-535) and Milestone 4."

## Overview

Phase 3 delivered the foundational read model — `AccountEngine` (master account registry),
`BudgetEngine`, and the `LinkingEngine`/`OverviewEngine` composition — with the Investments and Taxes
Overview cards deliberately left as a typed "data not available" stub. This feature builds the
**remaining domain engines** so every v1 module can produce complete projections, and replaces those
stubs with live data.

Five engine groups are in scope, plus the cross-domain completion that wires them into the Overview:

- **SavingsGoalEngine** — goal progress, gap-to-target, and months-to-goal at the current contribution
  rate; resolves budget contributions to goals.
- **PortfolioEngine** — the `Portfolio → Sleeve → Asset` read model: position values, cost basis,
  unrealized gain/loss, allocation, tax lots from trade history, dividends, and sleeve drift.
- **BenchmarkEngine** — S&P 500 comparison windows (D, W, M, 3M, 6M, 1Y, 3Y, 5Y), the heat-map data
  model, and sector performance weighting.
- **TaxEngine** — YTD taxable income per account, taxes paid, effective rate, realized gain/loss, and
  dividend/interest aggregation.
- **TaxAdjustmentEngine** + **TaxPrepEngine** — tax-adjustment / estimate / document records, standard
  adjustment seeding, the prep checklist, and the year-close → archive flow.

Cross-domain completion adds portfolio-to-tax and Schedule C links to `LinkingEngine` and updates
`OverviewEngine` to consume the real Investments and Taxes projections (removing the Phase 3 stubs).

This is an **engine/model/seed spec** in the same mold as Phase 3: it delivers domain logic,
projection models, seed data, and developer CLIs. It deliberately **excludes** all SwiftUI views and
UI design decisions (holdings tables, heat-map visuals, goal cards, tax screens, empty states) — those
land with the Phase 5 presentation spec.

> **Locked-decision references** (do not reopen — see `docs/technical-design.md §21`): trades live in
> the unified ledger as `type = trade` rows (the former `Investments/transactions.csv` is removed,
> R6); `Investments/benchmarks/sp500.csv` is the benchmark source; `Taxes/tax-adjustments.csv` carries
> an `adjustment_type` column (R6 rename of `deductions.csv`); tax year-close is an explicit in-app
> action only; a closed year's `Taxes/archive/YYYY-*.csv` files are read-only.

## Clarifications

### Session 2026-06-30

- Q: How is savings-goal progress derived when both a snapshot and ledger history exist? → A: Prefer
  the most recent explicit `SavingsProgress` snapshot as the balance anchor; in its absence, derive the
  balance from the ledger (sum of contributions tagged `savings_goal_id`, plus the linked savings
  account's derived balance where the goal maps 1:1 to an account). Snapshot wins on conflict.
- Q: What does the v1 "flat goal list, no lifecycle states" boundary mean for the engine, given
  `core-domain.md` defines `status ∈ {active, archived}`? → A: The engine reads `status` and excludes
  `archived` goals from active projections; `completed` is **derived** from progress ≥ target (not a
  stored state); `paused` is not in v1. The "flat list" boundary is a **UI** statement (no
  active/archived *grouping* on screen) — it does not remove the `archived` filter from the engine.
- Q: What % growth formula does BenchmarkEngine use per period? → A: Simple cumulative return
  `(end − start) / start` for periods ≤ 1Y; **CAGR** `(end / start)^(1/years) − 1` for the multi-year
  periods (3Y, 5Y), so multi-year cells are annualized and comparable. Both the S&P series and each
  portfolio account use the identical formula and calendar anchoring.
- Q: Where do standard-deduction amounts come from? → A: A hardcoded per-(filing-status, tax-year)
  table shipped with the release; the seeded standard adjustment row is written from
  `WorkspaceSettings.filingStatus` + `taxYear` at the applicable amount. New tax years require a code
  update (acceptable for v1; no live IRS lookup).
- Q: How are benchmark periods anchored on weekends / market-closed days? → A: Calendar-day anchoring
  with last-observation-carried-forward — the lookup for an anchor date that has no row uses the most
  recent prior row (the last close on or before the anchor). Gaps in the price history never crash;
  a period with no resolvable start anchor reports a typed "insufficient history" state.
- Q: Which tax-lot relief method computes realized gain/loss on sells? → A: **FIFO**
  (first-in-first-out) — the IRS default when no method is elected, deterministic, and hand-verifiable.
  Disposals consume the oldest open lots of the asset first; basis and holding period come from those
  lots.
- Q: What does "current contribution rate" mean for months-to-goal? → A: The **trailing 3-month
  average** of the goal's contributions, reusing the Phase 3 BudgetEngine trailing-average convention
  (with the same partial-average handling when fewer than 3 months exist).
- Q: How does the engine handle the standard-vs-itemized deduction choice? → A: **Compute both totals
  and flag the greater as recommended; do not auto-commit a choice.** The projection stays read-only
  and transparent — the UI/user makes the selection.
- Q: Where do dividend and interest income come from? → A: **Dividends from the dedicated
  `Investments/dividends.csv`; interest from categorized income rows in the unified ledger.** (The
  `dividends.csv` file already exists in the workspace layout; interest has no dedicated file.)
- Q: Does TaxEngine split realized gain/loss into short-term vs long-term? → A: **Yes** — classify each
  disposed FIFO lot by holding period (> 1 year = long-term) and report short-term and long-term
  realized gain/loss separately for the tax year.
- Q: How are tax-prep checklist items defined and what marks each state? → A: A **fixed v1 hardcoded
  item set** (W-2 income, 1099s, estimated payments, deduction confirmations); **missing** = the
  required source record/file is absent, **incomplete** = present but unconfirmed, **complete** =
  present and confirmed.
- Q: How is the Investments/Savings KPI card "estimated rate" computed? → A: **From a stored,
  user-entered expected-rate field — not derived.** Investments reads a portfolio expected-return-rate
  value; Savings reads the savings account's interest-rate/APY metadata. When the stored field is
  absent, the card reports a typed "rate not set" state (no computed fallback).
- Q: Does the tax module compute projected liability and safe-harbor, or only store estimates? → A:
  **Compute a simplified projection** — `projected_liability` from YTD taxable-income-minus-adjustments
  at the filing-status bracket, and `target_safe_harbor` from prior-year liability; a non-empty value
  in `Taxes/estimates.csv` overrides the computed one.
- Q: How is QBI handled in v1? → A: **Simplified 20% estimate** — QBI deduction ≈ 20% of qualified
  business-group net income, with no income-threshold phaseouts and no W-2/UBIA or SSTB limits.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Investment portfolio read model (Priority: P1)

The system reads `Investments/assets.csv`, `prices.csv`, `portfolios.csv`, `sleeves.csv`,
`sleeve-targets.csv`, and the `type = trade` rows of the unified ledger, and produces aggregate and
per-account holdings projections: current value (`quantity × latest price`), cost basis, unrealized
gain/loss, allocation per sleeve, tax lots from trade history, dividend totals, and each sleeve's
actual-vs-target weight with drift.

**Why this priority**: The portfolio read model is the largest new surface in Phase 4 and feeds both
the Investments Overview card and the Tax module's realized-gain inputs. It is the central deliverable
of Milestone 4.

**Independent Test**: Run the portfolio projection CLI against a fixture with assets, a price series,
a portfolio with sleeves and targets, and trade rows; confirm position values, cost basis, unrealized
gain/loss, sleeve allocation, and drift against hand-calculated figures — with no tax or benchmark
engine present.

**Acceptance Scenarios**:

1. **Given** assets with quantities and a price series, **When** the portfolio projection is built,
   **Then** each position's current value uses the latest available `close` for its ticker and
   unrealized gain/loss = current value − cost basis.
2. **Given** `type = trade` rows in the unified ledger, **When** holdings are built, **Then** trades
   are read from the ledger (not a separate investment-transactions file) and resolve into tax lots
   per asset.
3. **Given** a `Portfolio` with sleeves and `sleeve-targets`, **When** allocation is computed,
   **Then** each sleeve reports its actual weight, target weight, and drift (actual − target).
4. **Given** rows in `Investments/dividends.csv`, **When** the projection is built, **Then** dividend
   income totals are aggregated per asset and per account.
5. **Given** an asset whose ticker has no price row, **When** the projection is built, **Then** the
   position reports a typed "price unavailable" state rather than a zero or crash.

---

### User Story 2 - Tax read model (Priority: P1)

The system computes the Current Tax Year read model: YTD taxable income per account, taxes paid from
`EstimatedPayment` records, effective tax rate per account (taxes paid / gross income), realized
gain/loss from trade + lot history, and aggregated dividend and interest income.

**Why this priority**: The Tax module is the second core Milestone 4 deliverable and consumes the
portfolio realized-gain output; together with US1 it removes the two Phase 3 Overview stubs.

**Independent Test**: Run the tax projection CLI against a fixture with income transactions, estimated
payments, and trade history; confirm per-account taxable income, taxes paid, effective rate, and
realized gain/loss against hand-calculated figures.

**Acceptance Scenarios**:

1. **Given** income transactions across accounts, **When** the tax projection is built, **Then** YTD
   taxable income is computed per account anchored to the workspace `tax_year`
   (`Taxes/settings.csv`).
2. **Given** `Taxes/estimates.csv` / estimated-payment records, **When** taxes paid is computed,
   **Then** it sums payments for the tax year and the effective rate = taxes paid / gross income per
   account.
3. **Given** trade + lot history, **When** realized gain/loss is computed, **Then** it matches the
   disposed lots' proceeds − basis for the tax year, with lots relieved **FIFO** (oldest first) and the
   result split into short-term vs long-term by holding period.
4. **Given** `Investments/dividends.csv` and interest-categorized ledger income rows, **When** the
   projection is built, **Then** dividend and interest income are aggregated for the tax year.

---

### User Story 3 - Tax adjustments, estimates, documents, prep & archive (Priority: P2)

The system manages tax-adjustment, estimate, and document records; seeds the standard adjustment row
from filing status on first access; computes taxable-income-minus-adjustments; cross-references
business-expense adjustments with `AccountEngine`; evaluates the prep checklist; and manages the
year-close → read-only archive flow.

**Why this priority**: This completes the Taxes module (Current Tax Year deductions section, Prep
Checklist, Tax Archive) on top of the US2 read model. It depends on the tax read model but is
otherwise self-contained.

**Independent Test**: Run the tax-adjustments/prep CLI against a fixture; confirm the standard
adjustment seeds correctly, taxable-income-minus-adjustments computes, business-expense rows reconcile
to account-group expense totals, the checklist classifies each item, and a year-close writes a
read-only archive.

**Acceptance Scenarios**:

1. **Given** a workspace with no standard adjustment row, **When** the tax-adjustment engine is first
   accessed, **Then** it seeds the standard adjustment from `WorkspaceSettings.filingStatus` + `taxYear`
   at the applicable hardcoded amount.
2. **Given** adjustment rows of each `adjustment_type`, **When** taxable income minus adjustments is
   computed, **Then** above-the-line + Schedule C (`business-expense`) reduce taxable income and the
   standard-vs-itemized comparison returns both totals with the greater flagged (no auto-commit).
3. **Given** `business-expense` adjustments linked to an `account_group_id`, **When** the summary is
   built, **Then** each reconciles against that account-group's expense totals from `AccountEngine`.
4. **Given** available data, **When** the fixed v1 prep checklist (W-2, 1099s, estimated payments,
   deduction confirmations) is evaluated, **Then** each item is classified complete / incomplete /
   missing per its source-record presence and confirmation, and tax-relevant `ValidationIssue`s are
   surfaced as unresolved.
5. **Given** a year-close action, **When** the archive is written, **Then** `Taxes/archive/YYYY-*.csv`
   files are produced and that year is thereafter treated as read-only.

---

### User Story 4 - Benchmark comparison & heat map (Priority: P2)

The system loads the S&P 500 series from `Investments/benchmarks/sp500.csv`, computes % growth for the
8 benchmark periods using calendar-anchored lookups, computes the same periods for each portfolio
account, produces the heat-map data model (period × account), and computes sector performance weights
versus the benchmark.

**Why this priority**: The benchmark heat map is a holdings-table view toggle (not a standalone screen)
and enriches the Investments module; it depends on the portfolio read model from US1.

**Independent Test**: Run the benchmark CLI against a fixture with an S&P series and portfolio prices;
confirm each period's % growth (simple for ≤1Y, CAGR for 3Y/5Y) against hand-calculated figures and
that gap days resolve to the last prior close.

**Acceptance Scenarios**:

1. **Given** the S&P 500 series, **When** the 8 periods are computed, **Then** each uses calendar-day
   anchoring with last-close-on-or-before for missing anchor dates.
2. **Given** a portfolio account's value series, **When** its periods are computed, **Then** they use
   the identical formula and anchoring as the benchmark.
3. **Given** the multi-year periods (3Y, 5Y), **When** growth is computed, **Then** the result is CAGR
   (annualized), while ≤1Y periods are simple cumulative return.
4. **Given** holdings with sectors, **When** sector performance is computed, **Then** sector weights
   are derived from holdings and compared to the benchmark's sector weights.
5. **Given** a period whose start anchor predates the available history, **When** computed, **Then** it
   reports a typed "insufficient history" state rather than a misleading value.

---

### User Story 5 - Savings goal progress (Priority: P2)

The system computes per-goal progress from the most recent `SavingsProgress` snapshot or, in its
absence, derived from the ledger; computes gap-to-target and months-to-goal at the current
contribution rate; resolves each goal's `GoalFundingLink` to its monthly budget contribution rows; and
produces a `GoalProgressProjection` per active goal.

**Why this priority**: Savings goals complete the Savings & Investments module and make the Savings
Overview card richer, but the Phase 3 Savings card already works from account balances, so this is not
on the Milestone-4 critical path.

**Independent Test**: Run the savings projection CLI against a fixture with goals, progress snapshots,
and goal-tagged contributions; confirm progress, gap, months-to-goal, and funding-link resolution
against hand-calculated figures, and that archived goals are excluded.

**Acceptance Scenarios**:

1. **Given** a goal with a `SavingsProgress` snapshot, **When** progress is computed, **Then** the
   snapshot is the balance anchor; **Given** no snapshot, **Then** the balance is derived from the
   ledger.
2. **Given** a goal with a target and a current contribution rate, **When** the projection is built,
   **Then** gap-to-target = target − current and months-to-goal = ceil(gap / monthly contribution).
3. **Given** contributions tagged with a `savings_goal_id`, **When** links are built, **Then** each
   resolves to the originating budget contribution rows via `GoalFundingLink`.
4. **Given** a goal at or beyond target, **When** projected, **Then** it is reported as derived-
   complete (no stored `completed` state); **Given** an `archived` goal, **Then** it is excluded from
   active projections.

---

### User Story 6 - Cross-domain completion & projection CLIs (Priority: P3)

The system extends `LinkingEngine` with portfolio-to-tax links (realized gains → tax) and
business-entity Schedule C links, updates `OverviewEngine` to consume the real Investments and Taxes
projections (removing the Phase 3 stubs), and ships a developer CLI per engine consistent with the
Phase 3 CLI pattern.

**Why this priority**: This is the integration layer that proves Milestone 4 end-to-end; it depends on
all the engines above.

**Independent Test**: Run the overview CLI against a fixture and confirm all five KPI cards — including
Investments and Taxes — now carry live values, and each new engine's CLI prints a complete projection
summary.

**Acceptance Scenarios**:

1. **Given** the portfolio and tax engines, **When** the Overview cards are composed, **Then** the
   Investments and Taxes cards report live values (no "data not available" stub).
2. **Given** realized gains, **When** links are built, **Then** a portfolio-to-tax link feeds the tax
   engine's realized-gain input.
3. **Given** business-expense adjustments, **When** links are built, **Then** Schedule C categories
   link to the owning account-group for the deduction summary.
4. **Given** a fixture workspace, **When** each engine's CLI is run, **Then** it prints a complete,
   non-empty projection summary and writes nothing to the workspace.

### Edge Cases

- **No price data**: an asset with no matching price row reports "price unavailable"; the portfolio
  and benchmark projections never crash or zero-fill silently.
- **Sparse / short history**: a benchmark period whose start anchor predates the series reports
  "insufficient history"; fewer than one contribution month yields a typed months-to-goal of "n/a".
- **Market-closed anchor dates**: weekend/holiday anchors resolve to the last close on or before them.
- **Goal with no snapshot and no ledger trail**: progress is reported as zero-with-no-data, never a
  misleading positive.
- **Closed tax year**: any attempt to write to an archived year is rejected/warned; archive files are
  read-only.
- **Standard adjustment already present**: re-accessing the tax engine does not duplicate the seeded
  standard row.
- **Business-expense reconciliation mismatch**: a Schedule C row whose amount diverges from the
  account-group expense total is surfaced, not silently overwritten.
- **Missing estimated-rate field**: an Investments/Savings card whose stored expected-rate field is
  absent reports "rate not set" — never a derived or zero rate.

## Requirements *(mandatory)*

### Functional Requirements

**SavingsGoalEngine**

- **FR-001**: System MUST compute per-goal progress using the most recent `SavingsProgress` snapshot as
  the balance anchor, falling back to a ledger-derived balance (goal-tagged contributions, plus the
  linked savings account's derived balance for 1:1 goal-account mappings) when no snapshot exists.
- **FR-002**: System MUST compute gap-to-target (target − current) and months-to-goal at the current
  contribution rate — defined as the **trailing 3-month average** of the goal's contributions (Phase 3
  trailing-average convention, with partial-average handling under 3 months) — as gap ÷ that average,
  rounded up, returning a typed "n/a" when the rate is zero/unknown.
- **FR-003**: System MUST resolve each goal's `GoalFundingLink` to its monthly budget contribution rows
  (transactions tagged `savings_goal_id`).
- **FR-004**: System MUST exclude `archived` goals from active projections, derive `completed` from
  progress ≥ target (no stored completed state), and MUST NOT implement `paused` (out of v1).

**PortfolioEngine**

- **FR-005**: System MUST compute each position's current value from `quantity × latest available
  close` for its ticker, with cost basis and unrealized gain/loss (current value − cost basis).
- **FR-006**: System MUST read investment trades as `type = trade` rows from the unified ledger (the
  former `Investments/transactions.csv` is removed) and resolve tax lots per asset from trade history
  using **FIFO** relief — sells consume the oldest open lots first for basis and holding period.
- **FR-007**: System MUST model the `Portfolio → Sleeve → Asset` container hierarchy and compute, per
  sleeve, actual weight, target weight (from `sleeve-targets.csv`), and drift (actual − target).
- **FR-008**: System MUST build both aggregate and account-level holdings projections and aggregate
  dividend income totals per asset and per account from `Investments/dividends.csv`.
- **FR-009**: System MUST report a typed "price unavailable" state for any asset whose ticker has no
  price row (never a zero value or crash).

**BenchmarkEngine**

- **FR-010**: System MUST load the S&P 500 series from `Investments/benchmarks/sp500.csv` and compute
  % growth for the 8 periods (D, W, M, 3M, 6M, 1Y, 3Y, 5Y) using calendar-day anchoring with
  last-close-on-or-before resolution for missing anchor dates.
- **FR-011**: System MUST use simple cumulative return for periods ≤ 1Y and CAGR (annualized) for the
  3Y and 5Y periods, applying the identical formula and anchoring to both the benchmark and each
  portfolio account.
- **FR-012**: System MUST produce the heat-map data model (period × account) and compute sector
  performance weights from holdings compared to the benchmark's sector weights.
- **FR-013**: System MUST report a typed "insufficient history" state for any period whose start anchor
  predates the available series.

**TaxEngine**

- **FR-014**: System MUST compute YTD taxable income per account from income transaction records,
  anchored to the workspace `tax_year` (`Taxes/settings.csv`).
- **FR-015**: System MUST compute taxes paid per account from estimated-payment records and derive the
  effective tax rate per account (taxes paid ÷ gross income).
- **FR-016**: System MUST compute realized gain/loss for the tax year from trade + lot history (FIFO
  relief, per FR-006), reported **split into short-term and long-term** by each disposed lot's holding
  period (> 1 year = long-term), and aggregate dividend income (from `Investments/dividends.csv`) and
  interest income (from categorized income rows in the unified ledger) for the tax year.

**TaxAdjustmentEngine**

- **FR-017**: System MUST manage `TaxAdjustment`, `TaxEstimate`, and `TaxDocument` records over
  `Taxes/tax-adjustments.csv`, `Taxes/estimates.csv`, and `Taxes/documents.csv`, and MUST compute a
  simplified tax estimate — `projected_liability` from YTD taxable-income-minus-adjustments at the
  filing-status bracket (brackets from a hardcoded per-(filing-status, tax-year) table shipped in
  `WorkspaceLayout`, parallel to the standard-deduction table) and `target_safe_harbor` from prior-year
  liability — using a non-empty stored value in `estimates.csv` as an override when present.
- **FR-018**: System MUST seed the standard adjustment row on first access using
  `WorkspaceSettings.filingStatus` and `taxYear` at the applicable hardcoded amount, without
  duplicating an existing standard row. This seed is a deterministic "create-missing-seed" repair:
  previewable and logged to `.finance-meta/logs/repair-log.csv` alongside the backup, per constitution
  P-IV/P-VII.
- **FR-019**: System MUST compute taxable-income-minus-adjustments (above-the-line, Schedule C, and a
  **simplified QBI deduction ≈ 20% of qualified business income — defined in v1 as the net income of
  `group_type = business` account-groups** — with no threshold phaseouts or W-2/UBIA/SSTB limits) and a
  standard-vs-itemized comparison that returns **both** totals
  and flags the greater as recommended **without auto-committing** a choice; it MUST produce a
  `TaxDeductionSummary` across all adjustment categories.
- **FR-020**: System MUST cross-reference `business-expense` adjustments (by `account_group_id`) with
  `AccountEngine` account-group expense totals and surface divergences.

**TaxPrepEngine**

- **FR-021**: System MUST evaluate a **fixed v1 prep-checklist item set** (W-2 income, 1099s,
  estimated payments, deduction confirmations) against available data, classifying each as **missing**
  (required source record/file absent), **incomplete** (present but unconfirmed), or **complete**
  (present and confirmed), and surfacing tax-relevant `ValidationIssue`s as unresolved.
- **FR-022**: System MUST manage `TaxArchiveYear` read/write: on the year-close action, write the
  archive snapshot (`Taxes/archive/YYYY-tax-adjustments.csv` and
  `Taxes/archive/YYYY-estimated-payments.csv`, schema mirroring the active-year files), whose presence
  signals the year is closed, and enforce read-only access to a closed year thereafter (warn before any
  write).

**LinkingEngine & OverviewEngine completion**

- **FR-023**: System MUST extend `LinkingEngine` with portfolio-to-tax links (realized gains → tax
  engine) and business-entity Schedule C links (business categories → owning account-group).
- **FR-024**: System MUST update `OverviewEngine` so the Investments and Taxes KPI cards carry live
  values from `PortfolioEngine`/`BenchmarkEngine` and the tax engines, removing the Phase 3 typed
  "data not available" stubs.
- **FR-024a**: The Investments and Savings cards' **estimated rate** MUST be read from a stored,
  user-entered expected-rate field (a portfolio expected-return rate for Investments; the savings
  account's interest-rate/APY metadata for Savings) — **not derived** — and MUST report a typed
  "rate not set" state when that field is absent. These stored fields are **optional schema columns**
  — `expected_return_rate` on `portfolios.csv` and an APY/`interest_rate` field on the savings account
  in `accounts.csv` — registered in `CSVSchemaRegistry` and the bundled JSON schemas; an absent optional
  column is non-breaking.

**Cross-cutting**

- **FR-025**: Every engine MUST consume the Phase-2 parsing output (typed domain records) and degrade
  gracefully on empty, sparse, or partially-invalid inputs without crashing.
- **FR-026**: Each engine MUST be exercisable through a developer CLI that prints its projection
  summary against a workspace, consistent with the Phase 1–3 CLI pattern
  (`accounts-overview` / `budget-overview` / `overview-dashboard`).
- **FR-027**: Projections MUST be pure derivations of the files (regenerable, no hidden state) and MUST
  NOT write to the workspace — except the two explicitly stateful, user-confirmed write actions that
  belong to this domain: standard-adjustment seeding (FR-018) and the year-close archive (FR-022),
  both of which MUST use the Phase-1 safe-write primitives (backup + atomic apply).
- **FR-028**: Fixture/seed data MUST exist for the new file types so the engines are demonstrable: an
  S&P 500 benchmark series (`Investments/benchmarks/sp500.csv`), assets/prices/portfolios/sleeves, and
  tax estimates/documents — and a freshly bootstrapped workspace MUST validate with no errors.

### Key Entities *(include if feature involves data)*

- **GoalProgressProjection** — per-goal current balance, target, gap, months-to-goal, derived-complete
  flag, and funding links.
- **SavingsProgress / SavingsGoal** — snapshot balances and goal definitions (`status ∈ {active,
  archived}`; `completed` derived).
- **Portfolio / PortfolioSleeve / SleeveTarget** — the investment container hierarchy; sleeve actual
  vs target weight and drift.
- **Asset / PricePoint / Trade / Dividend** — holdings, the price series, ledger `type = trade` rows
  resolved into FIFO tax lots, and `Investments/dividends.csv` dividend records.
- **HoldingsProjection** — aggregate and per-account positions with current value, cost basis,
  unrealized gain/loss, dividends, and the "price unavailable" state.
- **BenchmarkPeriod** — the 8 comparison windows; the heat-map data model (period × account) and the
  "insufficient history" state.
- **TaxEstimate / TaxAdjustment / TaxDocument** — the tax records over `estimates.csv`,
  `tax-adjustments.csv`, `documents.csv`; `projected_liability` + `target_safe_harbor` are computed
  (simplified) with stored values overriding.
- **TaxDeductionSummary** — standard-vs-itemized, above-the-line, Schedule C, and taxable-income-minus-
  adjustments.
- **TaxArchiveYear** — the per-year archive snapshot and closed/read-only signal.
- **TaxPrepSummary** — the fixed v1 checklist items (W-2, 1099s, estimated payments, deduction
  confirmations) with complete/incomplete/missing classification.
- **RealizedGainSummary** — short-term and long-term realized gain/loss for the tax year (FIFO lots
  split by holding period).
- **GoalFundingLink / SleeveFundingLink** — cross-domain contribution links (populated from Phase 3
  stubs); the new portfolio-to-tax and Schedule C links.
- **OverviewSummaryCard** — the five KPI cards, now with live Investments and Taxes values.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Running every new engine's CLI against a 12-month fixture workspace produces complete,
  non-empty Savings, Portfolio, Benchmark, and Tax projections with no crashes.
- **SC-002**: Every position's current value, cost basis, and unrealized gain/loss reconciles to its
  assets/prices/trades inputs in the fixture (hand-calculated match).
- **SC-003**: Each sleeve's actual weight, target weight, and drift matches hand-calculated figures and
  sleeve actual weights sum to 100% of the portfolio's invested value.
- **SC-004**: Benchmark % growth matches hand-calculated values for all 8 periods, with ≤1Y simple
  return and 3Y/5Y CAGR, and weekend/holiday anchors resolving to the last prior close.
- **SC-005**: Per-account YTD taxable income, taxes paid, effective rate, and realized gain/loss
  (correctly split short-term vs long-term by FIFO holding period) match hand-calculated figures for
  the fixture tax year.
- **SC-006**: The standard adjustment row is seeded exactly once from filing status and is not
  duplicated on repeated engine access.
- **SC-007**: A year-close writes `Taxes/archive/YYYY-*.csv` and a subsequent write attempt to that
  year is rejected/warned (archive is read-only).
- **SC-008**: The Overview's Investments and Taxes cards report live values in 100% of Phase-4 runs
  (no "data not available" stub remaining), and all five cards reconcile to their engines.
- **SC-009**: No engine writes to the workspace during projection; the only writes are the
  user-confirmed standard-adjustment seed and the year-close archive, both backed up before apply.
- **SC-010**: A freshly bootstrapped workspace (including the seeded benchmark/asset/tax files)
  validates with zero errors and yields non-empty projections from all five new engines.
- **SC-011**: The computed `projected_liability` and `target_safe_harbor` match hand-calculated
  simplified figures for the fixture, and a non-empty stored value in `estimates.csv` overrides the
  computed one.
- **SC-012**: An Investments/Savings card with no stored expected-rate field reports "rate not set"
  (never a derived or zero rate), and one with a stored field reports exactly that value.

## Assumptions

- Scope is **engines + projection models + seed/fixture data + CLIs only**. All Phase-4 UI design
  DECIDEs (Goals overview, Portfolio holdings/heat-map, Current Tax Year, Prep Checklist, Tax Archive,
  empty states) are deferred to the Phase 5 presentation spec. No SwiftUI views are built here.
- Engines consume the existing Phase-2 parsing output (`WorkspaceParser` and the typed domain records)
  and the Phase-3 `AccountEngine`/`BudgetEngine` projections; no new parsing layer is introduced.
  Schema/validation for the R6 file set (assets, portfolios, tax-adjustments, estimates, documents,
  benchmark series) already shipped in Phase 2.
- Live price ingestion (endpoint, polling, error handling) is **out of v1** — prices come from the
  static `Investments/prices.csv` and `benchmarks/sp500.csv` files.
- Standard-deduction amounts **and tax-bracket rates** are hardcoded per-(filing-status, tax-year)
  tables in `WorkspaceLayout` (new tax years require a code update); QBI is a simplified ≈20%-of-
  qualified-business-income estimate (qualified = net income of `group_type = business` account-groups;
  no phaseouts / W-2 / UBIA / SSTB limits); tax-return filing is out of v1.
- Realized gain/loss uses **FIFO** lot relief, split short-term vs long-term; alternative methods
  (specific-ID, average cost, HIFO) are out of v1.
- The Investments/Savings "estimated rate" is a stored, user-entered assumption (portfolio
  expected-return rate / savings APY metadata), not a computed figure; a missing field yields a
  "rate not set" state rather than a derived fallback. The projected tax liability / safe-harbor
  *are* computed (FR-017), with stored `estimates.csv` values overriding.
- The "flat goal list" v1 boundary is a UI grouping statement; the engine still filters `archived`
  goals (reconciled with `core-domain.md`).
- `swift test` requires a full Xcode toolchain and runs in CI; a CLT-only machine builds and runs the
  CLIs but cannot run the test target. `swiftlint --strict` runs in CI.

## Dependencies

- **Phase 1** — workspace provisioning, file index, manifest, safe-write primitives
  (`BackupService` / `FileCoordinatorService` / `WriteGate`), core projection-model stubs.
- **Phase 2** — parsing + validation for the full R6 file set, `SettingsStore`
  (`WorkspaceSettings.filingStatus` / `taxYear`). Stable (merged PR #16).
- **Phase 3** — `AccountEngine` (master registry, business-group expense totals, retained-equity
  split), `BudgetEngine` (goal contributions), `LinkingEngine` / `OverviewEngine` (the stub contract
  this phase fills). Pending CI + merge of `004-domain-accounts-budget-overview`.
- **Build order** — PortfolioEngine (US1) before TaxEngine (US2, consumes realized gains) before the
  tax-adjustment/prep engines (US3); BenchmarkEngine (US4) after PortfolioEngine; SavingsGoalEngine
  (US5) independent; cross-domain completion + CLIs (US6) last.

## Out of Scope

- All SwiftUI views and the Phase-4 UI design DECIDEs (→ Phase 5).
- All write/edit/delete flows for these entities beyond the two stateful actions named in FR-027
  (standard-adjustment seed, year-close archive) — structured CRUD is Phase 6.
- Live market-data / price ingestion strategy, brokerage/bank sync, OCR ingestion, tax-return filing
  engine, full QBI calculation, and AI analysis (all → V2 per the roadmap Out-of-Scope table).
- Goal lifecycle states beyond `active`/`archived` (`paused`, explicit `completed`) → V2.
- Dedicated sleeves / benchmark / deductions screens (those surfaces live within existing screens) →
  V2.
