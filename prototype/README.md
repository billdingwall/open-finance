# Finance Workspace · Prototype

A static HTML/CSS/JS prototype for the v1 macOS Finance Workspace app. No build step, no
dependencies. The full requirements for what the prototype must cover are in
`specs/001-prototype-prd-alignment/spec.md`.

---

## Running the prototype

Open `prototype/index.html` directly in a browser. No server required.

```
open prototype/index.html        # macOS
start prototype/index.html       # Windows
```

The prototype starts on the Accounts screen. Use the left sidebar to navigate.

---

## Data model

`data.js` defines the canonical seed — a believable May 2026 snapshot of a single workspace.
The seed is a single `const DATA` IIFE that is never modified directly.

`store.js` is the persistence layer. On load, `Store.hydrate()` reads `localStorage` (key:
`finance-proto-workspace-v1`) and overlays any saved collections onto the seed. If nothing
is saved, the seed is shown as-is.

The 16 user-mutable collections are:

```
goals · transactions · categories · rules · accounts · entities
estimatedPayments · deductions · taxChecklist · issues · holdings
sleeves · sleeveTargets · notes · businessCategories · businessBudgets
```

Every mutation to DATA goes through `commit()`, which calls `Store.save() →
renderSidebar() → renderCenter() → renderInspector()`.

`businessTransactions` is a derived collection (always `transactions.filter(t => /^BX-/.test(t.id))`)
recomputed by `Store.syncDerived()` on every save and hydrate.

---

## Reviewer session guide

### Starting a fresh review

If the prototype has local edits from a previous session:

1. Open the prototype in a browser.
2. Navigate to **Settings › Workspace**.
3. Click **Reset prototype data** and confirm.
4. The page reloads with the seed dataset.

You can also clear `finance-proto-workspace-v1` from the browser's localStorage via DevTools
(Application › Storage › Local Storage) if the Reset button itself is broken.

### What persists across refreshes

All create, import, repair, and checklist changes persist until you reset. Specifically:

- Added goals, categories, accounts, entities, estimated payments
- Imported transactions (CSV upload or manual entry)
- Applied repairs (removed issues)
- Toggled checklist items

The following does **not** persist:

- The holdings view toggle (`state.holdingsMode`) — resets to `standard` on reload
- The current sync state (`state.syncState`) — resets to `synced` on reload

### Prototype Review Controls

**Settings › Workspace** contains a "Prototype Review Controls" section labeled explicitly
as non-app functionality. Four buttons:

| Button | Effect |
|---|---|
| Show onboarding flow | Navigates to the iCloud workspace states screen |
| Cycle sync state | Steps through synced → syncing → stale → error in the toolbar pill |
| Show indexing state | Navigates to the indexing progress screen |
| Reset prototype data | Confirms, then clears localStorage and reloads |

### OS-level action buttons

Buttons that would trigger native macOS actions (Reveal in Finder, Open in editor, file
downloads from the indexing screen) show a toast instead of performing the action. The toast
explains what the native app would do. This is intentional — the prototype runs in a browser.

---

## What is implemented

### Round 1 (visual design)
- App shell, three-column layout, slide-over inspector
- Five top-level navigation sections (Accounts, Budget, Savings & Investments, Taxes, Settings); the Overview dashboard is the default landing screen, reached via the sidebar header ("Finance Dashboard")
- Overview dashboard (5 KPI cards, issues table)
- Budget (pie chart, trailing averages, category variance table)
- Savings & Investments (goals, portfolio, holdings, heat map toggle, sleeve table)
- Taxes (current year with inline deductions/payments/gains, prep checklist, archive)
- Accounts (account-group grouping, single-screen group views with individual-account cards + inline ledger, dedicated per-account screens)
- Onboarding screen (7 iCloud states + success state)
- Sync status (4 toolbar pill states, 4 per-file badge states)
- Indexing progress screen
- Repair preview (before/after diff) in the issue inspector

### Round 5 (interactive flows + functional details)
- **Persistence** — `store.js`, `localStorage`, `commit()`, dirty-state note in Settings
- **Create flows** — New goal, import/add transaction, new category, new group, new account, import paystub, new estimated payment, import prices, rebalance plan, new business category
- **Edit & delete** — Every user-addable object can be edited and deleted: right-panel objects show Edit/Delete at the bottom of the inspector; the per-account screen edits via local actions with Delete inside the edit flow. Deletes run a reference check and preview before writing.
- **Real charts** — All charts render with Chart.js (vendored at `vendor/chart.umd.js`), not hand-drawn SVGs
- **Default dashboard** — Overview is the default screen; reached via the sidebar header, not a nav item
- **Account screens** — Group screens show individual-account cards above an inline ledger (no sub-tabs); account cards open a dedicated per-account screen
- **Header layout** — Issues chip sits in the top toolbar next to the sync chip; local actions sit on the page-title line
- **Repair** — Individual Apply repair (inspector) and bulk Apply repairable fixes (Overview header)
- **Checklist** — Tax prep checklist items toggle and persist
- **Export** — Real CSV and Markdown downloads from live data (10 export surfaces)
- **Live search** — Goals, Holdings, Budget ledger, Business ledger
- **OS action toasts** — Finder reveal, editor open, indexing download
- **Onboarding wiring** — Recovery actions produce toasts or navigation
- **Settings reset** — Danger button with confirmation modal

> Note: the contextual filter bar was removed in this round (deferred to V2).

---

## What is not yet implemented (known gaps)

See `specs/001-prototype-prd-alignment/spec.md §Known Gaps` for the full prioritized list.
Quick summary:

| Priority | Gap |
|---|---|
| P1 | Goal contribution recording |
| P1 | Designed empty states (no goals, no holdings, no transactions for a month, etc.) |
| P2 | Multi-month dataset (seed covers May 2026 only) |
| P2 | CSV import preview/validation step before commit |
| P3 | "Close Tax Year" action in Tax Archive (architecturally locked, not yet prototyped) |
| P3 | Account rules view and create flow |
| P3 | Investment transaction drill-down per holding |
| P4 | `tax-kpi` inspector kind (falls to generic fallback) |
| P4 | Modal accessibility (Esc-to-close, focus trap, ARIA roles) |

> Resolved in this round: edit/delete flows for all object types, the dedicated
> per-account screen, and deduction edit/delete.

---

## Updating the prototype

The prototype follows the same round-based revision cycle as the project-level docs
(documented in `docs/_notes/workflow-overview.md`). Round numbers are global — a prototype
update shares the same round number as any other doc update in that cycle.

### Checklist for a prototype round update

1. **Review feedback arrives** as `docs/_refinement/r{n}-review.md`.
2. **Plan prototype changes** — identify which screens, flows, or data need to change.
3. **Update `data.js`** if new mock data is needed (new entity types, additional months, new seed records).
4. **Update `app.js`** for view logic changes and new/changed interaction flows.
5. **Update `styles.css`** for any new component styles (add to the Round 5 component block or start a new block with a round comment).
6. **Update `store.js`** only if the set of mutable collections changes.
7. **Run the smoke test** (see below) to confirm no regressions.
8. **Update `specs/001-prototype-prd-alignment/spec.md`**:
   - Add a row to the Round History table.
   - Fix or add User Stories for any new flows.
   - Fix or add Functional Requirements (continue the FR numbering sequence).
   - Update Key Entities if new helpers or state fields were added.
   - Move resolved gaps out of Known Gaps; add new gaps that surfaced.
9. **Commit** all changed prototype files and the updated spec in the same commit.

### What to put where

| Content type | File |
|---|---|
| New mock data, seed records | `prototype/data.js` |
| View logic, create/import flows, export functions | `prototype/app.js` |
| New component styles | `prototype/styles.css` |
| Persistence layer changes | `prototype/store.js` |
| Feature requirements for the prototype | `specs/001-prototype-prd-alignment/spec.md` |
| Review process, session guide, known gaps summary | `prototype/README.md` (this file) |
| App-level product requirements | `docs/product-requirements.md` |
| App-level technical decisions | `docs/technical-design.md` |

Prototype-specific decisions (export column shapes, localStorage key, modal patterns) belong
in `spec.md`, not in `docs/product-requirements.md` or `docs/technical-design.md`.

---

## Smoke test

A jsdom headless harness was written during the Round 5 audit to verify the prototype without
a browser. It exercises: initial render, add-goal (form → DATA → badge → card → persist),
apply-repair, checklist toggle, manual transaction import, CSV export, filter-menu click,
all nav and entity views rendering without error, and persistence across a simulated reload.

**The harness is not committed to the repo.** It was run from a temporary location during the
audit. If you need to re-run it:

```
# Install jsdom in a temp location
mkdir /tmp/protosmoke && cd /tmp/protosmoke
npm init -y && npm install jsdom

# Write smoke.js (see the audit notes in docs/_notes/gap-analysis.md §3.7
# for the full test structure — concatenate data.js + store.js + app.js
# into a single eval, then assert against DATA and DOM state)

node smoke.js
```

The target is 19/19 passing assertions (as of Round 5). Add assertions for each new
interactive flow when updating the prototype.

Committing the harness to `prototype/smoke.js` (with `jsdom` as a dev dependency in a
`prototype/package.json`) is a P4 task tracked in Known Gaps.

---

## File reference

```
prototype/
  index.html      App shell, script load order: data.js → store.js → app.js
  data.js         Seed dataset (const DATA IIFE, ~740 lines, May 2026 snapshot)
  store.js        Persistence layer (localStorage, hydrate/save/reset/isDirty)
  app.js          All view logic, interaction infrastructure, and routing (~3,160 lines)
  styles.css      Design system + component styles (~1,100 lines)
  README.md       This file — process guide for reviewers and prototype maintainers
```
