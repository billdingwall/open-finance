# Quickstart: Domain Layer I — Accounts, Budget & Overview (Phase 3)

Validates the three read-model engines end-to-end against a local-folder workspace — no iCloud, no UI.

## Prerequisites

- Phase 1 + Phase 2 merged (workspace provisioning, file index, the parsing layer `WorkspaceParser`/
  `WorkspaceContext`, `ValidationEngine`, `SettingsStore`, domain model stubs).
- Swift 6 toolchain. `swift test` needs full Xcode (runs in `ci-macos.yml`); `swift build` +
  executables run on CLT-only.

## 1. Generate a fixture workspace

```bash
swift run fixture-generate --workspace ~/Finance-Dev --months 12     # 12-month baseline
swift run validate-workspace --workspace ~/Finance-Dev/Finance       # expect zero errors (incl. expanded seed)
```

## 2. Accounts read model (US1)

```bash
swift run accounts-overview --workspace ~/Finance-Dev/Finance --as-of 2026-06-30
```

Expect: per-account monthly inflow + YTD net income, with derived balances reconciling to the ledger;
internal transfers contribute zero to income/expense; business-group rows show a P&L; an account with
a rule but no current-month transactions shows `[projected]` figures.

## 3. Budget plan-vs-actual (US2)

```bash
swift run budget-overview --workspace ~/Finance-Dev/Finance --period 2026-06
```

Expect: planned/actual/variance per category; a trailing average per category with its months-
available label (a category with <3 months shows e.g. `avg of 1 mo`, never 0); spend-mix percentages;
goal-contribution rows for `savings_goal_id`-tagged transactions.

## 4. Overview dashboard (US3)

```bash
swift run overview-dashboard --workspace ~/Finance-Dev/Finance --as-of 2026-06-30
```

Expect: five KPI cards — Budget, Savings, Business with live values; **Investments and Taxes report
`data not available`** (Phase-4 engines absent); a trailing-6-month net-income panel that skips empty
months; the aggregated validation issue summary.

## 5. Determinism & read-only checks

```bash
# same as-of date → byte-identical output
swift run accounts-overview --workspace ~/Finance-Dev/Finance --as-of 2026-06-30 > /tmp/a1.txt
swift run accounts-overview --workspace ~/Finance-Dev/Finance --as-of 2026-06-30 > /tmp/a2.txt
diff /tmp/a1.txt /tmp/a2.txt && echo "deterministic ✓"
```

The engines never write — a projection run leaves the workspace bytes unchanged (asserted by tests,
SC-009).

## 6. Tests (CI / full Xcode)

```bash
swift test     # AccountEngine, BudgetEngine, Overview/Linking, RecordMappers, SeedData
```

Fixtures exercised: a multi-employment workspace, a sparse (<3-month) budget, a gap-month ledger, and
a paycheck-split + transfer group. Expect: balances reconcile (SC-002), YTD matches hand-calculated
figures with transfers neutral (SC-003), partial trailing averages report the right months-available
count (SC-004), stub cards are `data not available` (SC-005), the MoM panel skips gaps (SC-006), the
seed validates clean across six category groups (SC-007), and two employment groups aggregate without
collision (SC-008).
