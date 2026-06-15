# Product Roadmap Update Plan — Round 5

Source: `docs/product-requirements.md` + `docs/technical-design.md` (post r5-review), `docs/_refinement/r5-review.md`
Target: `docs/product-roadmap.md`
Status: Applied 2026-06-15

---

## Summary

Round 5 adds functional detail rather than new engines, so the roadmap impact is concentrated in
the **Phase 5 presentation layer** (app shell + Accounts module views) and the **Phase 6 write
flows** (delete becomes first-class). One item leaves scope (the filter bar → V2), one shared
component is deferred (`FilterBarView`), and the charts work is pinned to Swift Charts. No phase,
milestone, or domain engine is added or removed.

The deeper Budget⇄Strategy object model from the r5 "Notes on system objects" is **not** scheduled
here — it is deferred to a future object-model round (`docs/_notes/object-model-audit.md`).

---

## Change index

| # | Section | Type | Impact |
|---|---|---|---|
| 1 | Out of Scope for v1 | Addition | Contextual filter bar → V2 |
| 2 | Phase 5 → Dev → App Shell | Significant | Overview is default landing via header; issues chip in global header; local-actions on title row; no filter surface |
| 3 | Phase 5 → Dev → Shared UI | Minor | `FilterBarView` deferred to V2; chart components built on Swift Charts |
| 4 | Phase 5 → Dev → Accounts Module | Significant | Account-group detail view (cards + inline ledger, no sub-tabs) + per-account detail view |
| 5 | Phase 5 → Dev → Budget Module | Minor | Budget overview Spend Mix / Spending Variance 50/50 |
| 6 | Phase 5 → Design Tasks | Minor | Real charts; Accounts wireframes; shell layout changes |
| 7 | Phase 6 → Structured Write Flows | Significant | Add delete (with reference check) for every user-addable entity |
| 8 | Changelog | New | Add Round 5 entry |

---

## Detailed changes

### Out of Scope for v1

Add a row to the table:

| Item | Deferred to |
|---|---|
| Contextual filter bar / filter chips on module screens | V2 |

Note (like the existing estimated-payments note): inline period/account selection that a screen
intrinsically needs is still in v1; only the dedicated filter-bar surface is deferred.

### Phase 5 — Design Tasks

- **App Shell:** add tasks — Overview dashboard is the default landing screen reached via the
  sidebar header ("Finance Dashboard"); issues chip sits in the global header left of sync status;
  local-actions row aligns on the page-title line (right-aligned); no contextual filter bar.
- **Module Views → Accounts:** the "Finalize Accounts views wireframe" task expands to cover the
  account-group detail screen (individual-account cards + inline ledger, no sub-tabs) and the new
  per-account screen.
- **Charts:** note that all chart visuals are designed for a real charting implementation
  (Swift Charts), not placeholder SVGs.

### Phase 5 — Development Tasks

**App Shell**
- `AppState` / `AppRouter`: Overview is the **default selection on launch**; the sidebar header
  ("Finance Dashboard") navigates to it; Overview is no longer a sidebar nav row.
- `NavigationSidebarView`: remove the Overview nav item; rename the Accounts nested group to
  "Account groups"; "New group" action.
- Add an issues-count chip to the **global header** (left of the sync chip); move local-actions
  onto the page-title row.

**Shared UI Components (`UI/Shared/`)**
- Defer **`FilterBarView`** to V2 (filter bar removed from v1) — mark it accordingly rather than
  deleting the line.
- Note that `PieChartView`, `SparklineView`, and `HeatMapTableView` are implemented on **Swift
  Charts** (real charts).

**Accounts Module (`UI/Accounts/`)** — restructure:
- `AccountsView` — unchanged (all-accounts card grid + aggregate header), cards now navigate to
  the per-account screen.
- **`AccountGroupDetailView` (new/renamed):** account-group screen showing an **individual-account
  card section** above the transaction ledger; for business groups, the **ledger renders inline
  below the monthly net-income chart** with the P&L summary and category budgets — **no sub-tabs**.
- **`AccountDetailView` (per-account screen):** scoped to one account with a transactions table;
  reached by tapping an account card; edit in local actions, delete inside edit.

**Budget Module (`UI/Budget/`)**
- `BudgetOverviewView`: Spend Mix and Spending Variance panels share an equal **50/50** split.

### Phase 6 — Structured Write Flows (per entity)

Universal edit/delete (review functionality #6). Update this list so each entity supports
**add / edit / delete**, and add the delete-side rule:
- Add/edit/**delete** `Account` and **`AccountGroup`** (account groups are now deletable).
- Add/edit/**delete** `Transaction`, `Category` / `BudgetPlan`, `SavingsGoal`, holdings/assets,
  `DeductionRecord`, `AccountRule`.
- Add a **delete-with-reference-check** task: the write preview lists referencing rows and
  blocks/warns per the chosen default before applying (TDD §15). Pick the default behavior
  (block / cascade-warn / reassign) — open decision in `docs/_notes/object-model-audit.md` G7.
- Implement the **edit/delete UI placement convention**: right-panel objects show edit/delete at
  the panel bottom; dedicated-screen objects edit via local actions with delete inside edit.

### Open Decisions (Pre-Build)

Add: *"Default delete behavior when an object is referenced (block / cascade-warn / reassign)"* —
needed before Phase 6 delete flows.

---

## Items NOT changed

- Phases, milestones, dependency order — unchanged.
- All domain engines (Account, Budget, Savings, Portfolio, Benchmark, Tax) — unchanged.
- No object-model/file work scheduled (deferred — see `docs/_notes/object-model-audit.md`).

## Changelog stub (to add under product-roadmap.md Changelog)

```
### Round 5 — 2026-06-15
Source: docs/_refinement/r5-review.md (third prototype review — functional details)

- Out of Scope: added contextual filter bar (→ V2)
- Phase 5 App Shell: Overview is the default landing screen via the sidebar header ("Finance
  Dashboard"), not a nav item; issues chip moved to the global header; local-actions row moved to
  the page-title line; FilterBarView deferred to V2
- Phase 5 Accounts: account-group detail view shows individual-account cards + inline ledger
  (no sub-tabs); new per-account detail view reached by tapping account cards
- Phase 5 Budget: Spend Mix / Spending Variance panels set to 50/50
- Phase 5: chart components implemented on Swift Charts (real charts, not placeholder SVGs)
- Phase 6: every user-addable entity now supports delete (with a delete-with-reference-check
  rule) in addition to add/edit; added the edit/delete UI placement convention
- Open Decisions: added default delete-on-reference behavior
- Deeper Budget⇄Strategy object model deferred to a future round (docs/_notes/object-model-audit.md)
```
