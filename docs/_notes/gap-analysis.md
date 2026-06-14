# Prototype & Requirements Gap Analysis Report

**Date**: 2026-06-14
**Round**: r5 — functional details audit
**Author**: Engineering audit (prototype interactivity pass)
**Scope reviewed**:
- `docs/product-requirements.md` (PRD)
- `docs/technical-design.md` (TDD)
- `specs/001-prototype-prd-alignment/spec.md` (prototype spec)
- `prototype/` — `index.html`, `app.js` (2,877 → 3,160 LOC), `data.js`, `styles.css`, plus new `store.js`

**Method**: Full read of the three governing documents and the entire prototype source. Catalogued every interactive affordance (buttons, inputs, filters, rows) and traced whether it led anywhere. Fixed the glaring functional dead-ends, then verified with an automated jsdom smoke test (19 assertions, all passing).

---

## 1. Executive Summary

The prototype was **visually complete but functionally inert**. This is by original design: spec `001-prototype-prd-alignment` explicitly scoped the prototype to *visual fidelity only* ("Mock and placeholder data is acceptable throughout. Data accuracy is not a goal — visual design fidelity and interaction pattern clarity are." — spec.md, Assumptions). Every screen, chart, and KPI from the Round 1–4 PRD updates is present and correct, but **~28 primary action buttons** (`New goal`, `Import CSV`, `Export`, `Apply repair`, …) and most secondary affordances were rendered with no `onClick` — clicking them did nothing. There was also no persistence: the app held all state in a module-scoped `DATA` object that reset on every refresh.

This audit (Round 5) shifts the prototype from a *static design reference* to an *interactive flow prototype*, matching the new directive that "all user flows and app states [must be] accounted for… if a button says 'add X' I want to be able to click the next steps." The fixes added a small interaction infrastructure (modal/form builder, toast system, dropdown menus, real file export) and a `localStorage`-backed persistence layer (`store.js`) that mirrors the app's "files are the source of truth" model — the seed in `data.js` is the template; user edits layer on top and survive refresh until explicitly reset.

**Impact**: Every create/import/repair flow now opens a real form, validates input, writes to the data model, persists to `localStorage`, and re-renders. Every export produces a real downloaded CSV/Markdown file generated from live data. The repair flow, checklist, and OS-level affordances are wired. The result is a prototype a reviewer can *operate*, not just *look at*.

**Residual gaps** are concentrated in **edit/delete of existing records** (only create is implemented), **true data-driven filtering** (the single-month dataset limits what period/account filters can demonstrate), and a handful of **PRD/TDD omissions** the interactive build surfaced (per-account ledger screen, undefined empty states for several modules, no documented prototype write-flow). These are detailed in §4 and prioritized in §5.

---

## 2. Current State Assessment

### 2.1 What was fully functional before this audit

The structural and visual layer was solid and matched the PRD/spec:

| Area | Status before audit | Evidence |
|---|---|---|
| Navigation shell & IA | ✅ Correct | `NAV` array matches PRD §IA exactly: Overview, Accounts, Budget, Savings & Investments, Taxes, Settings (spec FR-001) |
| Three-column layout, slide-over inspector | ✅ Correct | `openInspector`/`closeInspector`; closed by default, overlays without shifting content (spec FR-005/006) |
| Inspector lineage detail | ✅ Functional | `renderInspector` handles 12 selection kinds (transaction, category, goal, holding, sleeve, biz-tx, issue, note, account, estimatedPayment, realized, overview-kpi) with source-file/row provenance |
| Navigation between views | ✅ Functional | `navigate()` with URL `?view=` history, `popstate` handling |
| Entity theme switching | ✅ Functional | `accounts-entity-<id>` route + entity strip pills + per-type dashboards (business/employment/personal) |
| Business entity tabs | ✅ Functional | Dashboard / Transactions / Budgets / Categories tab bar in `viewAccountEntity` |
| Holdings ⇄ heat-map toggle | ✅ Functional | `state.holdingsMode` toggle (spec FR-022) |
| Onboarding & sync states | ✅ Rendered | 8 iCloud states, 4 sync-pill states, indexing screen (spec FR-007–012) |
| Repair preview (diff) | ✅ Rendered | Before/after diff + backup note in inspector for repairable issues (spec FR-015/016) |
| Charts | ✅ Functional | `lineChart`, `barChart`, `donutChart` SVG helpers; heat-map table |
| Sync-state cycling (review control) | ✅ Functional | The only pre-existing working button (`Cycle sync state`) |

### 2.2 What was non-functional before this audit (the gap)

Every interactive affordance below rendered correctly but did nothing on click:

- **~28 header action buttons** with no `onClick`: `Export` (×9 views), `Reindex` (×2), `Import CSV` (×3), `New goal`, `New category`, `New entity` (×2), `New payment`, `New rule`, `New note`, `Import prices` (×2), `Rebalance plan`, `Export P&L` (×2), `Import Paystub`, `Add Asset`, `New` (biz category), `Export prep packet` (×2), `Apply repairable fixes`.
- **Inline panel buttons**: `Open file` (×2), `Download` (indexing), the empty-state `Add account (coming soon)`.
- **Inspector action buttons**: `Apply repair`, `Cancel`, `Reveal in Finder` (×2), `Open in editor` (×2).
- **Filter bar**: every filter chip rendered a caret but had `onClick: f.onClick || (() => {})` — a no-op.
- **Search inputs**: all `onChange: () => {}` — typing did nothing.
- **Tax prep checklist**: items called `select()` on a non-existent `tax-check` inspector kind; checkboxes never toggled.
- **Onboarding recovery actions**: `Open iCloud Settings`, `Retry`, `Download now`, `Start using app`, etc. — all inert.
- **Persistence**: none. Any change (had any been possible) reset on refresh.

---

## 3. Prototype Modifications & Fixes Applied

All changes are confined to `prototype/`. Net: **+1 new file (`store.js`), ~285 new lines in `app.js`, ~150 new lines in `styles.css`, 1 line in `index.html`.**

### 3.1 New persistence layer — `prototype/store.js` (new file)

- `Store.hydrate()` — on load, overlays any saved collections from `localStorage` onto the seed `DATA` and recomputes the derived `businessTransactions` projection.
- `Store.save()` — serializes the 16 user-mutable collections (`goals`, `transactions`, `categories`, `rules`, `accounts`, `entities`, `estimatedPayments`, `deductions`, `taxChecklist`, `issues`, `holdings`, `sleeves`, `sleeveTargets`, `notes`, `businessCategories`, `businessBudgets`) under key `finance-proto-workspace-v1`.
- `Store.reset()` — clears storage and reloads (the seed becomes canonical again).
- Wired into load order in `index.html`: `data.js` → `store.js` → `app.js`.

### 3.2 New interaction infrastructure — `app.js`

- `commit()` — the prototype stand-in for the TDD "structured write flow": persist → re-render sidebar/center → refresh inspector. Called after every mutation.
- `openModal({ title, fields, body, onSubmit, … })` / `closeModal()` — reusable form/dialog builder with text/number/date/select/textarea/file fields, required-field validation, and `field-error` styling.
- `toast(message, kind)` — transient confirmations (`ok`/`warn`/`info`).
- `openMenu(anchor, options, onPick)` — lightweight dropdown for filter chips.
- `downloadFile` / `toCSV` / `exportCSV` / `exportMarkdown` — **real** browser downloads generated from live data.
- `runReindex()` — pulses sync pill `syncing → synced` with a toast.
- `osAction(label, target)` — honest toast fallback for genuinely OS-level actions (Finder/editor reveal) that a browser cannot perform.

### 3.3 Create / import / edit flows wired

| Button (view) | New behavior |
|---|---|
| `New goal` (Savings Goals) | `addGoalFlow` → form → pushes to `DATA.goals`, updates sidebar badge, persists |
| `Import CSV` (Budget / Business) | `importTransactionsFlow` → **CSV file upload** (parses `date,merchant,description,category,amount`) *or* single manual add → pushes to ledger |
| `New category` (Budget) | `addCategoryFlow` → form (name/group/planned) → pushes to `DATA.categories` |
| `New` (Business Categories) | inline modal → pushes to `DATA.businessCategories` |
| `New entity` (Accounts / Business) | `addEntityFlow` → form (name/type/taxId) → new theme appears in sidebar + Accounts |
| `New account` / `Add account` / `Add Asset` | `addAccountFlow` → form → pushes to master `DATA.accounts` |
| `Import Paystub` (Employment) | `addPaystubFlow` → form → adds a payroll credit |
| `New payment` (Taxes) | `addPaymentFlow` → form → pushes to `DATA.estimatedPayments` with computed status |
| `Import prices` (Portfolio / Holdings) | `updatePriceFlow` → pick holding + new price → reprices, recomputes market value |
| `Rebalance plan` (Portfolio) | `rebalancePlanFlow` → computed drift→trade table modal, exportable |

### 3.4 Repair, checklist, export, reindex wired

- **Apply repair** (inspector) → `applyRepair(id)` removes the issue, decrements the count, closes inspector if selected, toasts "backup saved", persists. **Apply repairable fixes** (Overview header) bulk-repairs all repairable issues.
- **Tax prep checklist** → checkboxes call `toggleChecklistItem(id)`, flip `done`, persist.
- **Export** buttons → real CSV downloads (transactions, categories, goals, holdings, accounts, budget history, overview issues) and Markdown packets (`exportBusinessPL`, `exportTaxPacket`).
- **Reindex** → `runReindex`.

### 3.5 Smaller dead-ends closed

- Filter chips now open a real `openMenu` dropdown (options when supplied, current-value fallback otherwise) — no more dead carets.
- Search inputs on Goals, Holdings, and both transaction ledgers now live-filter rendered rows/cards.
- `Open file`, `Reveal in Finder`, `Open in editor`, `Download` → `osAction` toasts (truthful about being native actions).
- Onboarding recovery actions wired (`Start using app` → navigates to Accounts; others toast their intent).
- **Settings → Workspace** gained a `Reset prototype data` control (confirmation modal → `Store.reset()`) and a live note showing whether local edits exist.

### 3.6 Styling — `styles.css`

Added a self-contained component block (matching existing design tokens): `.modal-overlay/.modal/.modal-*`, `.proto-menu`, `.toast`, `.btn-danger`, form-field and `field-error` styles. No existing rules changed.

### 3.7 Verification

A jsdom smoke harness loads the real prototype, drives the flows, and asserts outcomes — **19/19 passing**, covering: initial render; add-goal flow (modal → DATA → sidebar badge → card render → persistence); apply-repair; checklist toggle; manual transaction import; CSV export; filter-menu click; **every nav view and every entity view rendering without throwing**; and **persistence surviving a simulated page reload** (added goal, repaired issue, and imported transaction all survive).

---

## 4. Remaining Gaps & Discrepancies

### 4.1 Requirements promise something the prototype still lacks

- **Edit & delete of existing records** *(PRD §5 "import, add, **and edit** of transactions"; §6 "category … editing"; §7 "create and **manage** savings goals"; "Limited structured editing for low-risk entities" — In scope v1).* The audit implemented **create** flows but not **edit/delete**. The inspector is read-only — there is no "Edit" affordance on a transaction, category, goal, account, or deduction, and no way to remove one. **This is the largest remaining functional gap.**
- **Per-account detail view** *(PRD §5: "Show a per-account view: monthly gross income vs expenses/tax, YTD net income…").* Clicking an account card opens the inspector with summary KVs, but there is no dedicated per-account ledger screen with its own transaction list and import/edit affordances.
- **Add/edit deductions & estimated-payment lifecycle** *(PRD §8).* `New payment` adds a payment, but payments cannot be marked paid/edited afterward, and the deductions table (`appendDeductionGroups`) is entirely read-only — no "add deduction" or status-change flow.
- **Savings-goal contribution recording** *(PRD §7: "Show monthly progress … Link savings goals to budgeted monthly contributions").* New goals are created with an empty `contributions` array; there is no flow to record a monthly contribution, so a newly added goal shows no funding history.
- **True period / account / sleeve filtering** *(PRD §6, §7).* Filter chips now open menus, but the dataset contains only **May 2026**, so period/account/sleeve selections cannot meaningfully re-filter the ledgers. The chips are interactive but not yet data-driven (most fall back to a confirmation toast).
- **CSV import preview/validation step** *(TDD §13 "Structured write flow": preview target file & affected rows before write; §3 CSV ingestion: "Produce warnings for extra or missing columns").* The implemented import appends rows directly; it does not show a pre-write preview or surface column-mismatch warnings.

### 4.2 Prototype evolved past the written requirements

- **localStorage write model is undocumented.** The prototype now simulates the TDD write/repair flow via `store.js` + `commit()`, but no document describes this. The PRD/TDD describe the *Swift* write flow (backup → atomic apply → re-index); the prototype's browser analogue should be recorded so reviewers know edits persist and how to reset them.
- **Real file export is now a demonstrated capability.** Exports produce actual CSV/Markdown downloads. The PRD §11 lists export as a requirement but the prototype now *demonstrates* it — worth noting the formats/columns chosen (e.g., `exportTaxPacket` emits a Markdown packet; `exportBusinessPL` emits a P&L) so they can be reviewed as the intended export shapes.
- **Bulk "Apply repairable fixes"** on Overview was added (it existed only as a label in the unreachable `viewIssues`). This is a sensible affordance but is not described in PRD §9 or spec FR-013–016, which only specify per-issue repair.
- **Spec 001's "no interactivity" assumption is now obsolete.** `specs/001-prototype-prd-alignment/spec.md` Assumptions state data accuracy/interactivity are non-goals. After Round 5 that is no longer true; the spec should be updated or superseded so it doesn't contradict the prototype's new purpose.

### 4.3 Edge cases & unaccounted states

- **Empty states are defined for only three surfaces** (Accounts grid, Budget all-zero donut, heat-map missing cell — per spec Edge Cases). Undefined/unhandled: **no savings goals**, **no holdings**, **no transactions for a selected month**, **no estimated payments**, **no business entities**. With create flows now live, a user *can* delete down toward these states (once delete exists), so they need designed empty states.
- **No-month-data handling is undemonstrable.** PRD "Data management" NFR requires graceful handling of sparse/missing months, but the dataset has a single month, so the prototype cannot show the empty-period state.
- **Two residual no-op search inputs** remain in **V2-deferred, non-navigable views** (`viewNotes` line ~2229, `viewIssues` line ~2339). Harmless (unreachable from nav) but should be wired or removed when/if those views return in V2.
- **Validation after edit isn't re-run.** Adding a zero-amount or duplicate-looking transaction does not generate a new validation issue (the validation engine is static mock data). The repair/validation loop is one-directional (you can clear issues, not create them).
- **Modal accessibility**: the new modal traps no focus and has no `Esc`-to-close or ARIA roles — acceptable for a prototype, but noted for the Swift build's dialog parity.

---

## 5. Next Steps & Action Items

Prioritized to reach full flow parity and to reconcile docs with the now-interactive prototype.

**P1 — Close the largest functional gaps (prototype)**
1. **Add edit + delete flows** for transactions, goals, categories, accounts, entities, deductions, and estimated payments. Reuse `openModal` with pre-filled `value`s; add a delete affordance (inspector "Edit"/"Delete" buttons) that mutates the array and `commit()`s. This directly satisfies PRD §5/§6/§7 "edit/manage."
2. **Record-a-contribution flow** for savings goals (appends to `contributions`, advances `balance`/`monthlyActual`) so progress and funding history are demonstrable.
3. **Designed empty states** for goals, holdings, transactions-for-month, payments, and entities — pair each with its create CTA.

**P2 — Make filtering data-driven (prototype + data)**
4. **Extend `data.js` to ≥3 months** of transactions so period/trailing-average/sparse-month flows become real, then wire the period/account/sleeve filter chips to actually filter (replacing the toast fallback).
5. **CSV import preview** step: show parsed rows + column-mismatch warnings before commit, mirroring TDD §13 and §3.

**P3 — Reconcile documentation with the interactive prototype**
6. **Document the prototype write model** (this `store.js` + `commit()` localStorage analogue, and the `Reset prototype data` control) — add a short section to `docs/_notes/workflow-overview.md` or a new `prototype/README.md`.
7. **Update `specs/001-prototype-prd-alignment/spec.md`** (or open a successor spec) to retire the "data accuracy / interactivity are non-goals" assumption and record the Round 5 interactivity requirements (create/import/export/repair/persist).
8. **Note the per-account detail view** as an explicit prototype surface in the PRD/roadmap (currently only an inspector summary exists for PRD §5's per-account view).
9. **Spec the bulk-repair and export shapes** (CSV columns, Markdown packet layout) in PRD §9/§11 so the demonstrated formats are intentional, not incidental.

**P4 — Polish**
10. Wire or remove the two residual no-op search inputs in the V2 `viewNotes`/`viewIssues` functions.
11. Add `Esc`-to-close, focus management, and ARIA roles to the modal for native-dialog parity.

---

### Appendix — Verification artifact

A jsdom smoke test (run during this audit) exercises the prototype end-to-end and asserts: initial render, add-goal (form→data→badge→card→persist), apply-repair, checklist toggle, manual transaction import, CSV export, filter-menu interaction, **all nav + entity views render without error**, and **persistence across a simulated reload**. Result at time of writing: **19/19 passing.** (The harness lives outside the repo; the prototype itself ships no test dependency.)
