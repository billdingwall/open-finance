# Phase 0 Research — Domain Layer II (Savings, Investments & Tax)

**Feature**: `005-savings-investments-tax` | **Date**: 2026-06-30

All decisions below are settled — the eleven material ambiguities were resolved across three
`/speckit-clarify` passes (spec §Clarifications). This file consolidates the resulting engineering
decisions, their rationale, and the alternatives rejected, so `data-model.md`, `contracts/`, and
`/speckit-tasks` can proceed without re-litigation.

## R1 — FIFO tax lots & short-term/long-term split

- **Decision**: Resolve tax lots per asset from the `type = trade` ledger rows using **FIFO** —
  a per-asset queue of open buy lots; a sell consumes the oldest lots first for cost basis and holding
  period. Realized gain/loss is reported **split short-term vs long-term** by each consumed lot's
  holding period (> 365 days = long-term).
- **Rationale**: FIFO is the IRS default absent an election, is deterministic (essential for
  hand-verifiable fixtures and `swift test`), and falls out naturally from chronologically ordered
  ledger rows. The ST/LT split is near-free once lots carry acquisition dates and matches how gains are
  actually taxed (feeds the simplified liability estimate in R3).
- **Alternatives rejected**: specific-identification (needs per-trade lot linkage not in the schema),
  average cost (loses per-lot holding period; wrong for equities), HIFO (non-standard, harder to
  validate).
- **Inputs**: `Trade` rows (sending/receiving asset, quantity, price, date) from the unified ledger;
  the optional `tax-lots.csv` schema exists but lots are **derived** from trade history (the file is
  not required input in v1).

## R2 — Benchmark period anchoring & return formula

- **Decision**: For each of the 8 periods (D, W, M, 3M, 6M, 1Y, 3Y, 5Y), anchor the start date by
  calendar arithmetic from the as-of date, then resolve the price via **last-close-on-or-before** the
  anchor (last-observation-carried-forward). Return = **simple cumulative** `(end − start)/start` for
  periods ≤ 1Y; **CAGR** `(end/start)^(1/years) − 1` for 3Y and 5Y. The identical formula and anchoring
  apply to the S&P 500 series and to each portfolio account's value series.
- **Rationale**: Calendar anchoring + carry-forward handles weekends/holidays/sparse series without
  special-casing; CAGR annualizes multi-year cells so a 5Y and a 1Y cell are comparable in the heat
  map. Symmetry between benchmark and portfolio keeps the comparison honest.
- **Edge state**: a period whose start anchor predates the available series returns a typed
  **"insufficient history"** state (not a misleading value). Sector weights are derived from current
  holdings; an asset with no `sector` is bucketed as `unclassified` rather than dropped.
- **Alternatives rejected**: trading-day-count anchoring (needs a market calendar, out of scope);
  simple return for all periods (multi-year cells then dwarf short ones and mislead).

## R3 — Tax computation: estimate, effective rate, QBI, standard deduction

- **Decision**:
  - **YTD taxable income per account** from income transaction rows, anchored to
    `WorkspaceSettings.taxYear` (reusing the Phase 3 per-group gross mapping); **effective rate** =
    taxes paid ÷ gross income per account.
  - **Projected liability** is **computed** (simplified): taxable-income-minus-adjustments at the
    filing-status bracket; **safe-harbor target** from prior-year liability. A non-empty
    `projected_liability` / `target_safe_harbor` in `Taxes/estimates.csv` **overrides** the computed
    value.
  - **Standard deduction** *and* **tax brackets** = hardcoded per-(filing-status, tax-year) tables
    shipped in `WorkspaceLayout`; new tax years require a code update (acceptable for v1). Brackets
    drive `projected_liability` from taxable-income-minus-adjustments.
  - **QBI** ≈ **20%** of qualified business income — v1 defines *qualified* as the net income of
    `group_type = business` account-groups — with **no** threshold phaseouts and no W-2/UBIA/SSTB
    limits (no SSTB exclusion).
  - **Standard vs itemized**: compute **both** totals, **flag the greater** as recommended, **do not
    auto-commit** — the projection stays read-only and the UI/user decides.
- **Rationale**: Honors the constitution's "Tax module estimates only, not a filing engine" boundary
  while still producing a meaningful Taxes card and prep view. Computed-with-override gives users a
  useful default without locking out manual entry. Simplified QBI is testable and within the v1
  "simplified estimate" scope.
- **Alternatives rejected**: store-only estimates (empty Taxes card until the user fills numbers);
  full QBI/bracket engine (large scope, conflicts with v1 boundary); auto-committing the larger
  deduction (opaque, bakes a decision into a read-only projection).

## R4 — Savings goal progress & rate

- **Decision**: Goal balance = the most recent `SavingsProgress` snapshot when present; otherwise
  ledger-derived (sum of `savings_goal_id`-tagged contributions, plus the linked savings account's
  derived balance for 1:1 goal-account mappings). Snapshot wins on conflict. Months-to-goal =
  ceil(gap ÷ **trailing-3-month average** contribution) — reusing the Phase 3 BudgetEngine trailing
  convention with the same partial handling; returns typed **"n/a"** when the rate is zero/unknown.
  `archived` goals are excluded; `completed` is **derived** from progress ≥ target (no stored state).
- **Rationale**: Snapshot-anchoring respects user-entered truth while still working when only a ledger
  exists. Trailing-3-month reuses an existing, tested convention and smooths sparse months. Filtering
  `archived` reconciles `core-domain.md`'s `{active, archived}` model with the "flat list" UI boundary.
- **Alternatives rejected**: latest-month rate (volatile); all-history average (slow to reflect pace
  changes); a stored `completed` state (redundant with derivable progress).

## R5 — Estimated rate (Investments & Savings KPI cards)

- **Decision**: The estimated rate is a **stored, user-entered** value — a portfolio expected-return
  field for Investments; the savings account's interest-rate/APY metadata for Savings — **not derived**.
  When the field is absent the card reports a typed **"rate not set"** state (no computed fallback).
- **Rationale**: User-selected at clarification (over the trailing-1Y-return alternative). Keeps the
  card honest about assumptions vs observed returns and avoids implying a derived figure the engine
  isn't computing. Note: this introduces an optional stored field; the engine reads it if present and
  degrades to "rate not set" otherwise (no schema break — optional column).
- **Alternatives rejected**: trailing-1Y return from BenchmarkEngine (recommended but not chosen);
  annualized total return value/cost (skewed by contribution timing).

## R6 — The two safe writes (standard-adjustment seed, year-close archive)

- **Decision**: Both stateful actions reuse the Phase 1 safe-write primitives —
  `BackupService` (timestamped backup) → atomic apply (temp file + rename) → `WriteGate`/
  `FileCoordinatorService` (sync-state gating). The standard-adjustment seed writes one templated row
  to `Taxes/tax-adjustments.csv` only when no standard row exists (idempotent) and logs it to
  `.finance-meta/logs/repair-log.csv` as a create-missing-seed repair (P-VII). Year-close writes
  `Taxes/archive/YYYY-tax-adjustments.csv` + `Taxes/archive/YYYY-estimated-payments.csv` (schema
  mirroring the active files); the archive file's presence marks the year closed, and subsequent writes
  to a closed year are rejected/warned.
- **Rationale**: The constitution mandates safe writes for *every* file mutation; reusing the existing
  primitives (rather than a new write path) keeps Principle IV satisfied with zero new complexity.
  Idempotent seeding and presence-as-closed-signal are deterministic and previewable.
- **Alternatives rejected**: reimplementing write logic (violates the CLAUDE.md "never reimplement
  safe-write" rule); a separate `closed` flag in settings (the archive-file-presence signal is already
  the architecture's locked convention, §3.24).

## R7 — Dividend & interest sourcing

- **Decision**: Dividends from the dedicated `Investments/dividends.csv`; interest income from
  interest-categorized `type = income` rows in the unified ledger. Both aggregated for the tax year.
- **Rationale**: `dividends.csv` already exists in the layout and has a shipped schema; interest has no
  dedicated file and fits the existing categorized-income model.
- **Alternatives rejected**: folding dividends into the ledger (deprecates an existing file); a single
  combined dividends-and-interest file (interest has no such file today).

## R8 — Engine purity, determinism & CLIs

- **Decision**: Every projection engine is a pure function of `WorkspaceContext` + an injected as-of
  date + `WorkspaceSettings`, returning `Sendable` value types. Four new executable targets
  (`savings-overview`, `portfolio-overview`, `benchmark-overview`, `tax-overview`) mirror the Phase 3
  CLI pattern and take `--workspace` + an `--as-of` / `--period` / `--tax-year` flag as appropriate;
  `overview-dashboard` is updated to render all five live cards.
- **Rationale**: Matches the established Phase 1–3 pattern; injected as-of date keeps tests
  deterministic; one CLI per engine gives an independent test surface per user story.
- **Alternatives rejected**: reading the system clock inside engines (non-deterministic tests); a
  single mega-CLI (loses per-engine independent testability).

## Build order (drives `/speckit-tasks` sequencing)

1. Record-mapping extension + `PeriodMath` helpers (shared seam) →
2. `PortfolioEngine` (US1) → `BenchmarkEngine` (US4, depends on portfolio value series) →
3. `TaxEngine` (US2, consumes realized gains) → `TaxAdjustmentEngine` + `TaxPrepEngine` (US3) →
4. `SavingsGoalEngine` (US5, independent) →
5. `LinkingEngine` + `OverviewEngine` completion (US6) → CLIs + seed/fixtures (US6).

**Output**: all `NEEDS CLARIFICATION` resolved; ready for Phase 1 design.
