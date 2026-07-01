# Contract — Engine Surfaces

**Feature**: `005-savings-investments-tax`

Every projection engine is a **pure function** of `WorkspaceContext` + an injected as-of date +
`WorkspaceSettings`, returning `Sendable` value types. Signatures are indicative (Swift 6); the
contract is the input → output behavior and the typed degradation states, not the exact API spelling.

## SavingsGoalEngine (read-only)

```
func projectGoals(context, asOf: Date) -> [GoalProgressProjection]
```

- Balance = latest `SavingsProgress` snapshot, else ledger-derived (FR-001/R4).
- `monthsToGoal` = ceil(gap ÷ trailing-3-month contribution); `nil` ("n/a") when rate ≤ 0 (FR-002).
- Resolves `GoalFundingLink`s from `savings_goal_id`-tagged rows (FR-003).
- Excludes `archived`; derives `isCompleteDerived` from progress ≥ target (FR-004).

## PortfolioEngine (read-only)

```
func projectHoldings(context, asOf: Date, scope: .aggregate | .account(id)) -> HoldingsProjection
```

- `currentValue` = quantity × last close ≤ asOf; `.priceUnavailable` when no price row (FR-005/009).
- Tax lots resolved FIFO from `type = trade` rows (FR-006/R1).
- Sleeve actual/target weight + drift from `sleeve-targets.csv` (FR-007).
- Dividend totals per asset/account from `dividends.csv` (FR-008/R7).

## BenchmarkEngine (read-only)

```
func heatMap(context, asOf: Date, accounts: [AccountID]) -> HeatMap
```

- Loads `benchmarks/sp500.csv`; 8 periods via calendar anchor + last-close-on-or-before (FR-010/R2).
- Simple return ≤1Y, CAGR for 3Y/5Y; identical formula for benchmark and each account (FR-011).
- `.insufficientHistory` when the start anchor predates the series (FR-013).
- Sector weights from holdings vs benchmark; `unclassified` bucket for assets without a sector (FR-012).

## TaxEngine (read-only)

```
func projectTax(context, asOf: Date, settings) -> (accounts: [AccountTaxProjection], realized: RealizedGainSummary)
```

- YTD taxable income per account, tax-year anchored (FR-014).
- Taxes paid from `estimated-payments.csv`; effective rate = paid ÷ gross (FR-015).
- Realized gain/loss FIFO, **split ST/LT** by holding period (FR-016/R1).
- Dividend (file) + interest (ledger income) aggregation (FR-016/R7).

## TaxAdjustmentEngine (read + one safe write)

```
func deductionSummary(context, settings) -> TaxDeductionSummary
func taxEstimate(context, settings) -> TaxEstimateProjection
func seedStandardAdjustmentIfMissing(workspace, settings) throws  // SAFE WRITE
```

- Standard vs itemized: returns both, flags greater, **no auto-commit** (FR-019/R3).
- QBI ≈ 20% qualified business-group net income, no phaseouts (FR-019/R3).
- Business-expense cross-ref vs `AccountEngine` group expense totals, surfaces divergence (FR-020).
- `projected_liability` + `target_safe_harbor` **computed**, stored `estimates.csv` overrides (FR-017/R3).
- `seedStandardAdjustmentIfMissing`: idempotent; routes through `BackupService` + atomic apply +
  `WriteGate` (FR-018/R6).

## TaxPrepEngine (read + one safe write)

```
func prepSummary(context, settings) -> TaxPrepSummary
func archiveYear(workspace, year, settings) throws -> TaxArchiveYear  // SAFE WRITE
func isYearClosed(workspace, year) -> Bool
```

- Fixed v1 checklist (W-2 / 1099s / estimated payments / deduction confirmations); states
  missing/incomplete/complete by source presence + confirmation (FR-021/R3).
- Surfaces tax-relevant `ValidationIssue`s as unresolved (FR-021).
- `archiveYear`: writes `Taxes/archive/YYYY-tax-adjustments.csv` + `YYYY-estimated-payments.csv` via the
  safe-write path; presence marks closed; subsequent writes to a closed year are rejected/warned
  (FR-022/R6).

## LinkingEngine (completion)

```
func portfolioTaxLinks(context) -> [PortfolioTaxLink]
func scheduleCLinks(context) -> [ScheduleCLink]
```

- Realized gains → tax engine input; business-expense adjustments → owning account-group (FR-023).

## OverviewEngine (completion)

```
func overview(context, asOf, settings) -> [OverviewSummaryCard]
```

- Investments + Taxes cards now **live** (from Portfolio/Benchmark/Tax engines); Phase-3 stubs removed
  (FR-024).
- Investments/Savings `estimatedRate` from the stored field; `.rateNotSet` when absent (FR-024a/R5).

## Cross-cutting invariants

- **No writes** except the two named safe writes (FR-025/027).
- Every engine degrades gracefully on empty/sparse/partially-invalid input — typed states, never crash
  / nil / misleading zero (FR-025).
- Deterministic under the injected as-of date.
