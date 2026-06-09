# Research: Prototype as Design Source of Truth

**Feature**: 001-prototype-prd-alignment
**Date**: 2026-06-08
**Status**: Complete — all decisions resolved from spec and existing prototype code

## Summary

This prototype is vanilla JS/CSS/HTML with no build step. All research questions are
design-pattern decisions within the prototype itself, not external technology choices.
All five open questions were resolved before tasking.

---

## Decision 1: Inspector slide-over mechanism

**Decision**: CSS `transform: translateX(100%)` → `translateX(0)` transition on a
fixed-position `<aside>` overlay. `<main>` width does not change. A backdrop `<div>`
behind the aside receives `onclick` to close.

**Rationale**: Matches FR-005 (hidden on load) and FR-006 (slide-over, not pushing content).
The current prototype has the inspector as a persistent split column — this must be replaced.

**Alternatives considered**:
- Persistent split column (current): Violates FR-005/FR-006. Rejected.
- `display: none / block` toggle with no animation: Functional but does not communicate
  "slide-over" interaction model to reviewers. Rejected.

---

## Decision 2: Onboarding flow placement

**Decision**: `onboarding` added as a navigable view ID reachable from
Settings → Workspace ("Show onboarding"). Renders as a 7-card grid, one card per iCloud
state. Each card shows: state name, icon, description, recovery action (where applicable).

**Rationale**: The spec explicitly allows this pattern. Avoids modifying the app entry
point or adding a transient modal that obscures the shell.

**Alternatives considered**:
- Full-screen modal on first load: Hides the shell, hard for reviewers to navigate back to
  individual states. Rejected.
- Standalone HTML page outside the app shell: Disconnects from the prototype navigation
  model. Rejected.

---

## Decision 3: Toolbar sync pill promotion

**Decision**: Move sync status from sidebar footer to the `#toolbar` element. Use a
`data-state` attribute cycling through: `synced`, `syncing`, `stale`, `error`.
A reviewer-facing toggle in Settings → Workspace lets any state be previewed.
Distinct colors and icons for each state (green checkmark / amber clock / red X / animated ring).

**Rationale**: Toolbar placement matches the macOS app spec (permanent toolbar element,
not sidebar footer). FR-010 requires 4 visually distinct states.

**Alternatives considered**:
- Keep in sidebar footer: Misrepresents macOS placement; not a toolbar affordance. Rejected.

---

## Decision 4: Benchmark heat map table

**Decision**: New `heatMapTable(rows, periods)` function produces an HTML `<table>` element.
Row headers = account names + S&P 500. Column headers = D, W, M, 3M, 6M, 1Y, 3Y, 5Y.
Each cell: a formatted % return value; CSS class `pos` (green tint) or `neg` (red tint)
based on sign. Missing data = `—` with no tint class.

**Rationale**: FR-022 specifies a heat map table, not a chart. The existing `lineChart` SVG
helper is replaced, not extended.

**Alternatives considered**:
- Extend `lineChart` helper: The heat map is fundamentally a table, not a chart. Rejected.
- CSS grid instead of `<table>`: Less semantic; harder to read in the prototype context. Rejected.

---

## Decision 5: FR-021 numbering gap

FR-001 through FR-025 are defined in the spec; FR-021 is absent. Confirmed as an intentional
artifact of the spec authoring process. No functional requirement is missing.

---

## No external research required

All other implementation details (pie chart reuse, trailing average column addition, NAV
restructure, deduction groups, per-account rate table) are straightforward edits to existing
code patterns. The `donutChart` SVG helper already exists and will be reused for Budget pie
chart (FR-019).
