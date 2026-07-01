# Contract — Developer CLIs

**Feature**: `005-savings-investments-tax`

Four new executable targets + one updated, mirroring the Phase 1–3 pattern
(`validate-workspace`, `accounts-overview`, `budget-overview`, `overview-dashboard`). Each is a thin
`main.swift` that parses a workspace, runs one engine with an injected as-of/period, and prints a
human-readable summary to stdout. **No writes** except the two explicit tax actions, which are
flag-gated and preview-by-default.

| CLI (target) | Engine | Flags | Prints |
|---|---|---|---|
| `savings-overview` | `SavingsGoalEngine` | `--workspace <path>` `--as-of <YYYY-MM-DD>` | per-goal balance, source, gap, months-to-goal, trailing rate, funding links |
| `portfolio-overview` | `PortfolioEngine` | `--workspace` `--as-of` `[--account <id>]` | positions (value/basis/unrealized, "price unavailable"), sleeve drift, dividend totals |
| `benchmark-overview` | `BenchmarkEngine` | `--workspace` `--as-of` | 8-period heat map (account × period), S&P row, sector weights, "insufficient history" cells |
| `tax-overview` | `TaxEngine` + `TaxAdjustmentEngine` + `TaxPrepEngine` | `--workspace` `--tax-year <YYYY>` `[--seed-standard] [--close-year]` | per-account taxable income/paid/rate, ST/LT realized gains, deduction summary (std vs itemized + QBI), tax estimate, prep checklist |
| `overview-dashboard` *(edited)* | `OverviewEngine` | `--workspace` `--as-of` | all **five** KPI cards now live (Investments + Taxes no longer stubbed); "rate not set" where applicable |

## `tax-overview` write flags (the two safe writes)

- `--seed-standard`: if no standard adjustment row exists, **preview** the row to be written; with
  `--apply` perform the safe write (backup + atomic). Idempotent (FR-018/R6).
- `--close-year`: **preview** the archive files for `--tax-year`; with `--apply` perform the year-close
  safe write and mark the year closed (FR-022/R6). Refuses if the year is already closed.

> Default (no `--apply`) is preview/read-only, consistent with `repair-workspace --dry-run`.

## Conventions

- Same arg-parsing style and exit-code convention as the existing CLIs (non-zero on hard error).
- As-of/tax-year flags make every run deterministic (R8) — required for the test fixtures.
- Output is plain text suitable for eyeballing and for `swift test` snapshot-style assertions; no JSON
  report in v1 (parity with the Phase 3 CLIs).
- Registered as `executableTarget`s in `Package.swift` (4 new), each depending on `FinanceWorkspaceKit`.
