# Contract: Developer CLIs

Three new `executableTarget`s, one per engine (FR-024), mirroring the Phase 1/2 CLIs
(`index-check`, `validate-workspace`). Each parses the workspace via `WorkspaceParser`, loads
`WorkspaceSettings` via `SettingsStore`, runs its engine, and prints a readable summary to stdout.
Exit 0 on success; exit 2 on usage error; exit 1 on unreadable workspace.

Common flags:
- `--workspace <path>` (required) — the `Finance/` workspace directory.
- `--as-of YYYY-MM-DD` (optional, default = today) — the injected as-of date for deterministic runs.

## `accounts-overview` (US1)

```
swift run accounts-overview --workspace ~/Finance-Dev/Finance [--as-of 2026-06-30]
```

Prints: as-of month + tax year; per-account rows (display name, group, monthly inflow, YTD net
income, derived balance, `[projected]` marker when figures came from rules/estimates); per-group
subtotals incl. business P&L lines; aggregate totals.

## `budget-overview` (US2)

```
swift run budget-overview --workspace ~/Finance-Dev/Finance [--budget <budget_id>] [--period YYYY-MM] [--as-of …]
```

`--budget` defaults to the first/only budget; `--period` defaults to the as-of month. Prints: per
category — planned, actual, variance, and trailing average with its months-available label
(e.g. `avg of 1 mo`); the spend-mix percentages; budget totals; goal-contribution rows.

## `overview-dashboard` (US3)

```
swift run overview-dashboard --workspace ~/Finance-Dev/Finance [--as-of …]
```

Prints: the five KPI cards with their state (Budget/Savings/Business with values; Investments/Taxes
as `data not available`); the trailing-6-month month-over-month net-income panel (populated months
only); the aggregated validation issue count + grouped summary.

## Package.swift

Add three `.executableTarget` entries depending on `FinanceWorkspaceKit`, alongside the existing
`validate-workspace` / `repair-workspace` / `migrate-r6` targets. Update `CLAUDE.md`'s Build & test
block with the three new `swift run …` lines.

## Determinism

With a fixed `--as-of`, output is byte-stable for a given workspace (enables snapshot-style CLI
checks and reproducible docs/QA runs). No CLI writes to the workspace (read-only, SC-009).
