# Data Model: Prototype as Design Source of Truth

**Feature**: 001-prototype-prd-alignment
**Date**: 2026-06-08

This document describes the prototype's data structures — the mock data constants in `data.js`
and the key in-memory state shape in `app.js`. These are not Swift entities; they are the
prototype data layer.

---

## State object (`app.js → state`)

```js
{
  view: string,           // Current view ID (matches NAV item IDs)
  selection: null | {     // Currently selected item
    kind: string,         // 'transaction' | 'issue' | 'holding' | 'goal' | 'account'
    id: string
  },
  filters: {              // Per-view filter state, keyed by view ID
    [viewId]: object
  },
  navCollapsed: Set,      // Set of nav group IDs currently collapsed
  syncState: string,      // NEW: 'synced' | 'syncing' | 'stale' | 'error'
  inspectorOpen: boolean  // NEW: replaces always-visible inspector
}
```

**Changes from current**: Add `syncState` and `inspectorOpen` fields.

---

## NAV structure

See [contracts/nav-structure.md](contracts/nav-structure.md) for the canonical NAV array.

---

## Mock data additions (`data.js`)

### `DATA.accounts` — master account registry (NEW)

```js
[{
  id: string,             // e.g. 'checking-main'
  name: string,           // e.g. 'Chase Checking'
  institution: string,    // e.g. 'Chase'
  group: string,          // e.g. 'Everyday Banking'
  type: string,           // e.g. 'checking'
  monthlyInflow: number,  // mock monthly cash inflow in USD
  ytdNetIncome: number    // mock YTD net income in USD
}]
```

Minimum 4 mock accounts covering at least 3 distinct account groups.

### `DATA.iCloudStates` — onboarding flow states (NEW)

```js
[{
  id: string,             // e.g. 'available', 'not-signed-in', 'syncing', ...
  label: string,          // Display name
  icon: string,           // Unicode or emoji icon for prototype display
  description: string,    // User-facing description
  recoveryAction: string | null  // CTA label, or null if no action
}]
```

All 7 states defined:
`available`, `not-signed-in`, `container-unavailable`, `syncing`,
`local-copy-stale`, `file-missing-locally`, `conflict-detected`

Plus one success state: `workspace-created`

### `DATA.benchmarkPeriods` — benchmark heat map columns (NEW or extracted from existing)

```js
['D', 'W', 'M', '3M', '6M', '1Y', '3Y', '5Y']
```

### `DATA.benchmarkReturns` — heat map cell data (NEW or extended from existing)

```js
[{
  accountId: string,      // Matches DATA.investmentAccounts[].id or 'sp500'
  label: string,          // Display name
  returns: {              // Keyed by period ID
    D: number | null,
    W: number | null,
    M: number | null,
    '3M': number | null,
    '6M': number | null,
    '1Y': number | null,
    '3Y': number | null,
    '5Y': number | null
  }
}]
```

### `DATA.deductions` — tax deductions (NEW)

```js
[{
  id: string,
  type: string,           // 'standard' | 'above-line' | 'schedule-a' | 'schedule-c'
  name: string,
  estimatedAmount: number,
  status: string          // 'confirmed' | 'estimated' | 'missing'
}]
```

At least 2 entries per deduction type for prototype display.

### `DATA.accountTaxRates` — per-account tax rate table (NEW)

```js
[{
  accountId: string,
  accountName: string,
  taxableIncome: number,
  taxesPaid: number,
  taxesOwed: number,
  effectiveRate: number   // decimal, e.g. 0.22
}]
```

---

## Existing mock data unchanged

- `DATA.transactions` — personal transactions
- `DATA.categories` — personal categories
- `DATA.budgets` — budget rows
- `DATA.goals` — savings goals
- `DATA.investmentAccounts` — investment accounts
- `DATA.holdings` — portfolio holdings
- `DATA.sleeves` — portfolio sleeves
- `DATA.entities` — business entities
- `DATA.businessTransactions` — business transactions
- `DATA.businessCategories` — business categories
- `DATA.issues` — validation issues (extended with additional mock entries for prototype display)

---

## Key view function signatures

These are the main render functions being added or changed. Full implementations in `app.js`.

| Function | Status | Description |
|---|---|---|
| `viewOverviewDashboard()` | Modified | Remove filter bar; fix KPI card set to exactly 5; add inline Issues table |
| `viewBudgetOverview()` | Modified | Rename from `viewBudgetCurrent()`; add pie chart; add trailing average column |
| `viewSavingsInvestments()` | New (hub) | Top-level Savings & Investments view, replaces separate savings/investments entry points |
| `viewInvestmentsBenchmarks()` | Modified | Replace line chart with `heatMapTable()` |
| `viewAccounts()` | New | Card grid with aggregate header; uses `DATA.accounts` |
| `viewTaxesDeductions()` | New | Four deduction group sections; uses `DATA.deductions` |
| `viewTaxesCurrent()` | Modified | Add per-account effective rate table; uses `DATA.accountTaxRates` |
| `viewOnboarding()` | New | 7-state iCloud card grid; uses `DATA.iCloudStates` |
| `heatMapTable(rows, periods)` | New (helper) | Returns `<table>` element for benchmark view |
| `renderInspector()` | Modified | Now controlled by `state.inspectorOpen`; renders as slide-over |
| `openInspector(kind, id)` | New | Sets selection, sets `inspectorOpen = true`, renders inspector |
| `closeInspector()` | New | Clears selection, sets `inspectorOpen = false`, removes slide-over |
