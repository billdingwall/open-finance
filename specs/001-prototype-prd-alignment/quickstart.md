# Quickstart: Prototype Review Guide

**Feature**: 001-prototype-prd-alignment
**Prototype location**: `prototype/`

## Opening the prototype

1. Open `prototype/index.html` in a browser (no server required — file:// works).
2. The prototype loads immediately with no build step.
3. Default view on load: **Accounts** (the `accounts-overview` screen).

## Reviewing each user story

| Story | Where to look |
|---|---|
| US1 — App shell and navigation | Read the sidebar top-to-bottom. Confirm section order. Check toolbar. |
| US2 — Right inspector slide-over | Select any table row. Confirm panel slides in from right without shifting content. Click outside to close. |
| US3 — First-launch onboarding | Go to Settings → Workspace → "Show onboarding." Review all 7 iCloud state cards. |
| US4 — Sync status and indexing | Inspect the toolbar sync pill. Cycle states via Settings → Workspace. Open any detail view to see per-file sync badges. |
| US5 — Validation issue card and repair preview | Go to Overview. Scroll to Issues table. Select a repairable issue; confirm diff preview in inspector. Select a manual issue; confirm no Apply button. |
| US6 — Overview dashboard | Go to Overview. Count KPI cards (expect 5). Confirm no filter bar. Scroll to Issues table. |
| US7 — Budget module | Go to Budget → Overview. Confirm pie chart. Confirm trailing average column. Confirm no Rules entry in sidebar. |
| US8 — Savings & Investments | Confirm single section in sidebar. Navigate to Benchmarks. Confirm 8 period columns in table. |
| US9 — Taxes expanded + Accounts | Go to Taxes → Deductions. Confirm 4 labeled groups. Go to Accounts. Confirm card grid with at least 2 cards. |

## Checking success criteria

- **SC-002** (no V2 views reachable): Walk every sidebar section. Notes, Issues, Files, Rules, Monthly Snapshots, Annual Snapshots must not appear.
- **SC-003** (no JS errors): Open browser DevTools console before navigating. Navigate to every section. Zero errors expected.
- **SC-006** (inspector closed on load): Reload the page. Confirm right panel is absent.

## Modifying sync state for review (US4)

Settings → Workspace has a "Sync state" toggle button that cycles through:
`synced` → `syncing` → `stale` → `error` → back to `synced`.
The toolbar sync pill updates immediately.

## Source files

| File | Contains |
|---|---|
| `app.js` | All JavaScript: state, NAV, view render functions, helpers |
| `styles.css` | All styles including inspector slide-over, heat map, sync pill |
| `index.html` | Shell HTML: sidebar, toolbar, main content area, inspector aside |
| `data.js` | All mock data constants (DATA object) |
