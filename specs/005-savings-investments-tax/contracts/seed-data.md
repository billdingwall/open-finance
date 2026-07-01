# Contract — Seed & Fixture Data

**Feature**: `005-savings-investments-tax`

## Standard-deduction table (hardcoded, in `WorkspaceLayout`)

A per-(filing-status, tax-year) lookup shipped with the release (R3). Filing status from
`WorkspaceSettings.filingStatus`; tax year from `WorkspaceSettings.taxYear`. New tax years require a
code update (acceptable for v1).

| filing_status | covered years | source |
|---|---|---|
| single | current + prior tax year | hardcoded constant table |
| married_filing_jointly | current + prior tax year | hardcoded constant table |
| married_filing_separately | current + prior tax year | hardcoded constant table |
| head_of_household | current + prior tax year | hardcoded constant table |

> The exact dollar amounts are filled at implementation time from the published figures for the
> workspace's tax years; the contract is the table shape + sourcing, not the literals.

## Tax-bracket table (hardcoded, in `WorkspaceLayout`) — §1a

A per-(filing-status, tax-year) ordered bracket list `[(upperBound: Decimal, rate: Decimal)]` used to
compute `projected_liability` from taxable-income-minus-adjustments (R3). Same shape, sourcing, and
caveat as the standard-deduction table (new tax years require a code update). Covers the same filing
statuses (single / married_filing_jointly / married_filing_separately / head_of_household) for the
current + prior tax year. Literals are filled at implementation time from the published figures for the
workspace's tax years; the contract is the table shape + sourcing, not the values.

## Seeded standard tax-adjustment row (safe write, R6)

On first access (or bootstrap), if `Taxes/tax-adjustments.csv` has **no** `adjustment_type = standard`
row for the current `tax_year`, write one:

- `adjustment_type = standard`, `tax_year = settings.taxYear`,
  `estimated_amount = standardDeduction(filingStatus, taxYear)`, `status = estimated`,
  `name = "Standard Deduction"`.
- **Idempotent**: never duplicates an existing standard row.
- Routes through `BackupService` + atomic apply + `WriteGate`; keeps the `# schema_version: N` comment
  row and existing R6 headers (no schema change — a row, not a column).

## Bootstrap seed files (new, via `WorkspaceLayout`)

A fresh workspace must validate clean (FR-028/SC-010). Seed empty-but-valid (header-only +
`# schema_version`) files for the new file types not already seeded: `Investments/dividends.csv`,
`Investments/portfolios.csv`, `Investments/sleeves.csv`, `Investments/sleeve-targets.csv`,
`Investments/benchmarks/sp500.csv`, `Savings/progress.csv`, `Taxes/estimates.csv`,
`Taxes/documents.csv` (any already seeded in Phase 1–2 are left as-is).

## Fixture data (via `fixture-generate`, for tests + CLIs)

Realistic 12-month data so the engines are demonstrable end-to-end:

- **Investments**: ≥2 assets with a multi-month `prices.csv` series; `type = trade` ledger rows
  including a **multi-lot buy then partial sell spanning the 1-year ST/LT boundary** (FIFO + ST/LT
  test); a portfolio with ≥2 sleeves + sleeve-targets (drift); `dividends.csv` rows.
- **Benchmark**: an `sp500.csv` series with weekend/holiday gaps and a start that makes the 5Y period
  fall before the series (insufficient-history test).
- **Savings**: ≥2 goals — one **with** a `progress.csv` snapshot, one **without** (ledger-derived
  path); goal-tagged contributions for the trailing-rate test; one `archived` goal (exclusion test).
- **Taxes**: income rows + `estimated-payments.csv` (effective rate); a `business-expense` adjustment
  linked to a business account-group (Schedule C cross-ref); `estimates.csv` with one stored override
  and one empty (computed) row; `documents.csv` rows covering some-but-not-all prep items (checklist
  states); a prior closed year under `Taxes/archive/` (read-only test).

## Acceptance

- `bootstrap-workspace` then `validate-workspace` → **zero errors** (SC-010).
- `fixture-generate` output drives all four new CLIs to non-empty projections (SC-001).
- Hand-calculated fixture figures match engine output for FIFO ST/LT gains (SC-005), sleeve drift
  (SC-003), benchmark periods (SC-004), tax estimate + override (SC-011), and "rate not set" (SC-012).
