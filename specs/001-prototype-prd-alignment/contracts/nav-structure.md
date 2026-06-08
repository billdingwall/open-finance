# Contract: NAV Array and View ID Registry

**Feature**: 001-prototype-prd-alignment
**Date**: 2026-06-08

This document is the canonical contract for the `NAV` constant in `app.js` and the view ID
registry. Any change to sidebar structure must update this document.

---

## Canonical NAV array (target state)

```js
const NAV = [
  { id: 'overview', label: 'Overview', items: [
    { id: 'overview-dashboard', label: 'Dashboard' },
  ]},
  { id: 'accounts', label: 'Accounts', items: [
    { id: 'accounts-overview', label: 'All Accounts' },
  ]},
  { id: 'budget', label: 'Budget', items: [
    { id: 'budget-overview',    label: 'Overview' },
    { id: 'budget-history',     label: 'Budget History' },
    { id: 'budget-categories',  label: 'Categories' },
  ]},
  { id: 'savings-investments', label: 'Savings & Investments', items: [
    { id: 'savings-goals',            label: 'Goals' },
    { id: 'savings-goals-active',     label: 'Active Goals', badge: dynamic },
    { id: 'savings-goals-archived',   label: 'Archived Goals', badge: dynamic },
    { id: 'investments-portfolio',    label: 'Portfolio Overview' },
    { id: 'investments-accounts',     label: 'Accounts' },
    { id: 'investments-sleeves',      label: 'Sleeves' },
    { id: 'investments-holdings',     label: 'Holdings' },
    { id: 'investments-benchmarks',   label: 'Benchmarks' },
  ]},
  { id: 'business', label: 'Business', items: [
    { id: 'business-all-entities',  label: 'All Entities' },
    { id: 'business-monthly',       label: 'Monthly Performance' },
    { id: 'business-categories',    label: 'Categories' },
    { id: 'business-budgets',       label: 'Budgets' },
    { id: 'business-entity',        label: 'Consulting LLC' },
  ]},
  { id: 'taxes', label: 'Taxes', items: [
    { id: 'taxes-current',    label: 'Current Tax Year' },
    { id: 'taxes-deductions', label: 'Deductions' },
    { id: 'taxes-estimated',  label: 'Estimated Payments' },
    { id: 'taxes-gains',      label: 'Gains & Income' },
    { id: 'taxes-checklist',  label: 'Prep Checklist' },
  ]},
  { id: 'settings', label: 'Settings', items: [
    { id: 'settings-workspace', label: 'Workspace' },
    { id: 'settings-schema',    label: 'Schema' },
  ]},
];
```

---

## Removed from current NAV

| Removed ID | Reason |
|---|---|
| `overview-monthly` | Monthly Snapshots deferred to V2 (FR-002) |
| `overview-annual` | Annual Snapshots deferred to V2 (FR-002) |
| `personal-budget-current` | Renamed to `budget-overview` |
| `personal-budget-history` | Renamed to `budget-history` |
| `personal-budget-categories` | Renamed to `budget-categories` |
| `personal-budget-rules` | Budget Rules deferred to post-MVP (FR-002) |
| `savings` group | Merged into `savings-investments` group (FR-003) |
| `investments` group | Merged into `savings-investments` group (FR-003) |
| `notes` group | Notes deferred to V2 (FR-004) |
| `issues` group | Issues surfaced inline in Overview (FR-004) |

---

## Added to current NAV

| Added ID | Reason |
|---|---|
| `accounts` group | New Accounts section (FR-025) |
| `accounts-overview` | Accounts card grid view |
| `savings-investments` group | Merged Savings & Investments (FR-003) |
| `taxes-deductions` | Deductions sub-view (FR-023) |
| `budget-overview` | Replaces `personal-budget-current`; renamed for clarity |

---

## Default view on load

`accounts-overview` — the prototype defaults to the Accounts screen when no section is
selected (US1, acceptance scenario 5). This is set as the initial `state.view` value.

---

## View ID registry (all reachable view IDs)

| View ID | Render function | Module |
|---|---|---|
| `overview-dashboard` | `viewOverviewDashboard()` | Overview |
| `accounts-overview` | `viewAccounts()` | Accounts |
| `budget-overview` | `viewBudgetOverview()` | Budget |
| `budget-history` | `viewBudgetHistory()` | Budget |
| `budget-categories` | `viewBudgetCategories()` | Budget |
| `savings-goals` | `viewSavingsGoals()` | Savings & Investments |
| `savings-goals-active` | `viewSavingsGoals({ filter: 'active' })` | Savings & Investments |
| `savings-goals-archived` | `viewSavingsGoals({ filter: 'archived' })` | Savings & Investments |
| `investments-portfolio` | `viewInvestmentsPortfolio()` | Savings & Investments |
| `investments-accounts` | `viewInvestmentsAccounts()` | Savings & Investments |
| `investments-sleeves` | `viewInvestmentsSleeves()` | Savings & Investments |
| `investments-holdings` | `viewInvestmentsHoldings()` | Savings & Investments |
| `investments-benchmarks` | `viewInvestmentsBenchmarks()` | Savings & Investments |
| `business-all-entities` | `viewBusinessAllEntities()` | Business |
| `business-monthly` | `viewBusinessMonthly()` | Business |
| `business-categories` | `viewBusinessCategories()` | Business |
| `business-budgets` | `viewBusinessBudgets()` | Business |
| `business-entity` | `viewBusinessEntity()` | Business |
| `taxes-current` | `viewTaxesCurrent()` | Taxes |
| `taxes-deductions` | `viewTaxesDeductions()` | Taxes |
| `taxes-estimated` | `viewTaxesEstimated()` | Taxes |
| `taxes-gains` | `viewTaxesGains()` | Taxes |
| `taxes-checklist` | `viewTaxesChecklist()` | Taxes |
| `settings-workspace` | `viewSettingsWorkspace()` | Settings |
| `settings-schema` | `viewSettingsSchema()` | Settings |
| `onboarding` | `viewOnboarding()` | Settings (linked from settings-workspace) |
