# Phase 1 Data Model — Domain Layer II (Savings, Investments & Tax)

**Feature**: `005-savings-investments-tax` | **Date**: 2026-06-30

Two layers: (A) **mapped domain entities** — typed structs the record-mapping seam produces from
`ParsedRecord`s (column sources in `docs/architecture/containers-and-budgets.md §3`); and (B)
**projection models** — the value-type outputs of the engines (flesh out the Phase-1/3 stubs in
`Domain/{Savings,Investments,Taxes,CrossDomain}/*Models.swift`). All types are `Sendable` value types
and carry `source_file`/`source_row` provenance where they map 1:1 to a file row.

## A. Mapped domain entities (record-mapping extension)

| Entity | Source file | Key fields | Notes |
|---|---|---|---|
| `Asset` | `Investments/assets.csv` | `asset_id`, `account_id`, `asset_class`, `ticker?`, `quantity`, `cost_basis`, `sleeve_id?`, `sector?`, `as_of_date` | `current_value` is **derived** (R1), not read |
| `PricePoint` | `Investments/prices.csv` | `ticker`, `date`, `close` | Indexed by ticker → sorted dates for last-close lookup |
| `Trade` | unified ledger `type = trade` | `transaction_id`, `date`, `account_id`, `trade_type` (buy/sell), `sending_asset_id?`/`receiving_asset_id?`, `quantity`, `price`, `sleeve_id?` | Source of FIFO lots (R1) |
| `Dividend` | `Investments/dividends.csv` | `asset_id`/`ticker`, `account_id`, `date`, `amount` | Dividend income aggregation (R7) |
| `Portfolio` | `Investments/portfolios.csv` | `portfolio_id`, `name`, `type`, `strategy?`, `account_group_ids?` | Container above sleeves |
| `Sleeve` | `Investments/sleeves.csv` | `sleeve_id`, `portfolio_id`, `name`, `target_allocation_percentage`, `monthly_contribution_target`, `benchmark_id?` | |
| `SleeveTarget` | `Investments/sleeve-targets.csv` | `sleeve_id`, `ticker`, `target_weight`, `min_weight`, `max_weight` | Per-ticker target within a sleeve |
| `BenchmarkPoint` | `Investments/benchmarks/sp500.csv` | `date`, `close`, `source` | The S&P 500 series |
| `SavingsGoal` | `Savings/goals.csv` | `goal_id`, `name`, `target_amount`, `target_date?`, `monthly_contribution_target?`, `account_id?`, `status` (active/archived) | `completed` is derived, not stored |
| `SavingsProgress` | `Savings/progress.csv` | `goal_id`, `date`, `balance` | Snapshot anchor (R4) |
| `TaxAdjustment` | `Taxes/tax-adjustments.csv` | `tax_adjustment_id`, `tax_year`, `adjustment_type` (standard/above_the_line/itemized/business-expense/credit/liability), `name`, `estimated_amount`, `confirmed_amount?`, `account_group_id?`, `status` | Standard row is seeded (R6) |
| `TaxEstimate` | `Taxes/estimates.csv` | `estimate_id`, `fiscal_year`, `estimated_income`, `estimated_deductions`, `projected_liability`, `target_safe_harbor?` | Stored values **override** computed (R3) |
| `TaxDocument` | `Taxes/documents.csv` | `document_id`, `name`, `file_path`, `tax_year`, `type` (income-form/deduction-receipt/prior-return/other) | Drives prep-checklist source links |
| `EstimatedPayment` | `Taxes/estimated-payments.csv` | `date`, `tax_year`, `amount` | Taxes-paid input (FR-015) |

Estimated-rate inputs (R5): an optional stored `expected_return_rate` on `Portfolio` (Investments) and
the existing `interest_rate`/APY metadata on the savings `Account` (Savings). Both optional; absence →
"rate not set".

## B. Projection models (engine outputs)

### Savings (`Domain/Savings/SavingsModels.swift`)

- **`GoalProgressProjection`** — `goalId`, `name`, `targetAmount`, `currentBalance`,
  `balanceSource` (`.snapshot` | `.ledgerDerived`), `gapToTarget`, `monthsToGoal` (`Int?` → "n/a"),
  `trailingContributionRate` (value + months-available), `isCompleteDerived: Bool`,
  `fundingLinks: [GoalFundingLink]`. Archived goals excluded.

### Investments (`Domain/Investments/InvestmentModels.swift`)

- **`Position`** — `assetId`, `ticker?`, `quantity`, `costBasis`, `currentValue: ValueState`
  (`.value(Decimal)` | `.priceUnavailable`), `unrealizedGainLoss: ValueState`, `accountId`, `sleeveId?`,
  `sector`.
- **`TaxLot`** — `assetId`, `acquiredDate`, `quantity`, `costBasisPerUnit`, `remainingQuantity` (FIFO
  consumption state).
- **`SleeveAllocation`** — `sleeveId`, `actualWeight`, `targetWeight`, `drift` (actual − target),
  `marketValue`.
- **`HoldingsProjection`** — `scope` (`.aggregate` | `.account(id)`), `positions: [Position]`,
  `sleeveAllocations: [SleeveAllocation]`, `dividendTotalsByAsset`, `dividendTotalsByAccount`,
  `totalMarketValue`.
- **`BenchmarkCell`** — `period: BenchmarkPeriod`, `growth: GrowthState`
  (`.simple(Decimal)` | `.cagr(Decimal)` | `.insufficientHistory`).
- **`HeatMap`** — `rows: [account/benchmark] × columns: [BenchmarkPeriod]` of `BenchmarkCell`, plus an
  S&P 500 comparison row and a `sectorPerformance: [sector: weightVsBenchmark]` block.

### Taxes (`Domain/Taxes/TaxModels.swift`)

- **`RealizedGainSummary`** — `taxYear`, `shortTermGainLoss`, `longTermGainLoss`, `total`,
  `lots: [RealizedLot]` (each tracing to its trade rows; FIFO, R1).
- **`AccountTaxProjection`** — `accountId`, `ytdTaxableIncome`, `taxesPaid`, `effectiveRate`,
  `dividendIncome`, `interestIncome`.
- **`TaxDeductionSummary`** — `standardTotal`, `itemizedTotal`, `recommended`
  (`.standard` | `.itemized`, the greater; **not auto-committed**), `aboveTheLine`, `scheduleC`,
  `qbiDeduction` (≈20% simplified), `taxableIncomeAfterAdjustments`,
  `businessExpenseByGroup: [accountGroupId: (claimed, accountEngineTotal, divergence)]`.
- **`TaxEstimateProjection`** — `fiscalYear`, `projectedLiability` (computed | stored override),
  `targetSafeHarbor` (computed from prior year | stored override), `source` (`.computed` | `.stored`).
- **`TaxPrepSummary`** — `items: [PrepItem]` over the fixed v1 set
  (`.w2Income`, `.form1099`, `.estimatedPayments`, `.deductionConfirmations`); each
  `PrepItem` = `kind`, `state` (`.missing` | `.incomplete` | `.complete`), `sourceLinks: [TaxDocument]`,
  `unresolvedIssues: [ValidationIssue]`.
- **`TaxArchiveYear`** — `year`, `isClosed: Bool` (= archive files present), `archivedFiles: [path]`.

### CrossDomain (`Domain/CrossDomain/CrossDomainModels.swift`)

- **`PortfolioTaxLink`** — `realized gains (RealizedGainSummary) → TaxEngine input` (FR-023).
- **`ScheduleCLink`** — `account-group business expenses → TaxAdjustment business-expense rows` (FR-023).
- **`OverviewSummaryCard`** (extended) — Investments and Taxes cards now carry **live** values;
  `estimatedRate: RateState` (`.value(Decimal)` | `.rateNotSet`) on the Investments/Savings cards
  (R5). The Phase-3 typed "data not available" stub is removed for these two.

## State & lifecycle

- **Tax year**: `active` (the workspace `tax_year`) vs `closed` (an archive file exists). Year-close is
  the one lifecycle transition with a write (R6); a closed year is read-only thereafter.
- **Savings goal**: `active` (projected) vs `archived` (excluded); `complete` derived from progress,
  not a stored state.
- **FIFO lot**: open → partially-consumed → closed as sells consume quantity (derived in-memory, not
  persisted).

## Validation rules (consumed, not introduced)

Phase 2 already ships schemas + rules for every file above (`Resources/Schemas/*`). This phase adds no
new validation rules; it **consumes** the existing rule output: dangling `account_id`/`asset_id`/
`sleeve_id`/`goal_id` references and bad enums surface through `ValidationEngine`, and `TaxPrepEngine`
reads tax-relevant `ValidationIssue`s as unresolved checklist signals (FR-021).

## Determinism

All projections are pure functions of (`WorkspaceContext`, injected as-of date, `WorkspaceSettings`);
no engine reads the system clock or persists derived state. The only persisted artifacts are the two
safe writes (standard-adjustment seed, year-close archive), both idempotent/previewable.
