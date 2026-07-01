# Contract — Record Mapping (`ParsedRecord` → typed entities)

**Feature**: `005-savings-investments-tax`

Extends the existing `Domain/Mapping/RecordMappers.swift` seam. Each mapper takes the Phase 2
`ParsedRecord` (typed-but-generic field bag with `source_file`/`source_row`) and produces a typed
entity, preserving provenance. Column names per `docs/architecture/containers-and-budgets.md §3`.

| Mapper | From | Produces | Notable rules |
|---|---|---|---|
| `mapAsset` | `assets.csv` | `Asset` | `current_value` ignored on read (derived); `ticker` required only when `asset_class = equity` |
| `mapPricePoint` | `prices.csv` | `PricePoint` | grouped into `[ticker: [sorted PricePoint]]` for lookup |
| `mapTrade` | unified ledger rows where `type = trade` | `Trade` | uses `trade_type`, `sending_asset_id`/`receiving_asset_id`, `quantity`, `price`, `sleeve_id` |
| `mapDividend` | `dividends.csv` | `Dividend` | keyed by `asset_id`/`ticker` + `account_id` |
| `mapPortfolio` | `portfolios.csv` | `Portfolio` | optional pipe-delimited `account_group_ids`; optional `expected_return_rate` (R5) |
| `mapSleeve` | `sleeves.csv` | `Sleeve` | `portfolio_id` re-parents the sleeve |
| `mapSleeveTarget` | `sleeve-targets.csv` | `SleeveTarget` | per-ticker target/min/max weight |
| `mapBenchmarkPoint` | `benchmarks/sp500.csv` | `BenchmarkPoint` | sorted by date |
| `mapSavingsGoal` | `goals.csv` | `SavingsGoal` | `status` defaults to `active`; unknown → surfaced via validation |
| `mapSavingsProgress` | `progress.csv` | `SavingsProgress` | latest by `date` per `goal_id` is the anchor |
| `mapTaxAdjustment` | `tax-adjustments.csv` | `TaxAdjustment` | `adjustment_type` enum; `business-expense` carries `account_group_id` |
| `mapTaxEstimate` | `estimates.csv` | `TaxEstimate` | empty `projected_liability`/`target_safe_harbor` → use computed |
| `mapTaxDocument` | `documents.csv` | `TaxDocument` | `type` enum drives prep source links |
| `mapEstimatedPayment` | `estimated-payments.csv` | `EstimatedPayment` | taxes-paid input, tax-year filtered |

## Invariants

- **Provenance preserved**: every mapped entity carries through `source_file`/`source_row` (Principle V).
- **No silent invention**: a missing required column or bad enum is left to `ValidationEngine` (already
  shipped) — mappers do not fabricate defaults beyond documented optionals.
- **Optional columns**: `expected_return_rate` (portfolios) and the savings APY (`interest_rate` on
  accounts) are **registered optional columns** in `CSVSchemaRegistry` + the bundled JSON schemas
  (`portfolios.schema.json`, `accounts.schema.json`); read if present, treated as absent otherwise —
  adding an optional column is non-breaking per the constitution. Registration is a Foundational task
  so a workspace carrying these columns validates under Phase 2's strict schema enforcement.
- **Trades come from the ledger**, never a separate investment-transactions file (removed in R6).
- Mappers are pure and `Sendable`; grouping/indexing (e.g. price-by-ticker, progress-latest-by-goal) is
  done once and passed to engines.
