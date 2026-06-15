# Implementation Plan: Prototype as Design Source of Truth

**Branch**: `001-prototype-prd-alignment` | **Date**: 2026-06-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-prototype-prd-alignment/spec.md`

## Summary

Update the static HTML/CSS/JS prototype at `prototype/` to match the interface
decisions made during Round 1 design review and to cover all open design tasks from roadmap
Phases 1 and 2. The prototype is pure front-end (no build step, no dependencies) — all changes
are edits to `app.js`, `styles.css`, `index.html`, and `data.js`.

## Technical Context

**Language/Version**: Vanilla JavaScript (ES2020), CSS, HTML5 — no transpilation, no bundler
**Primary Dependencies**: None. The prototype uses no external libraries.
**Storage**: None. All data is in-memory via `data.js` constants.
**Testing**: Manual browser review. No automated test suite.
**Target Platform**: Modern desktop browser (Safari, Chrome). Designed for macOS viewport widths.
**Project Type**: Static design prototype
**Performance Goals**: Instantaneous navigation (no network, no async). All views render in < 100ms.
**Constraints**: All changes must stay within `prototype/`. No new files outside that folder. No new dependencies.
**Scale/Scope**: ~9 user stories, ~25 functional requirements, 4 source files.

### Round 5 Amendments (2026-06-14)

The following Technical Context fields were updated by the Round 5 interactive pass:

- **Storage**: `store.js` module added — localStorage-backed persistence under key `finance-proto-workspace-v1`. 16 mutable collections overlaid onto seed DATA on load. `commit()` is the single write pipeline: `Store.save() → renderSidebar() → renderCenter() → renderInspector()`.
- **Source files**: 5 files (was 4). `store.js` added; `prototype/README.md` added as reviewer process doc.
- **Scale/Scope**: 14 user stories (was 9), 71 active FRs (was ~25), 5 source files (was 4).
- **Testing**: jsdom smoke test run from `/tmp/protosmoke` during Round 5 audit — 19/19 assertions passed (SC-013). Committing `prototype/smoke.js` is a P4 Known Gap. Manual review remains the primary acceptance gate.
- **Dependencies**: `jsdom` used for smoke test only (temp install, not committed to repo).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

This prototype is a **design artifact**, not the macOS application. Constitution principles
govern the macOS app implementation. However, the prototype must not contradict any principle
it represents visually — it is the design reference the app will be built from.

| Principle | Relevance to Prototype | Status |
|-----------|----------------------|--------|
| I. Plain Files First | Prototype uses no database; data.js is inline mock data | ✅ No conflict |
| II. Read Model Second | Not applicable to prototype (no parsing layer) | ✅ N/A |
| III. Native Over Generic | Prototype must model `NavigationSplitView` conventions: stable sidebar, collapsible right pane, keyboard-navigable structure | ✅ Must reflect |
| IV. Safe Writes Only | Repair preview panel must show diff + backup note before Apply; `commit()` is the write-flow stand-in; Reset requires confirmation modal | ✅ Must reflect (FR-015, FR-030, FR-062) |
| V. Traceability Always | File path chips and source links must appear in issue cards and inspector views | ✅ Must reflect (FR-013, FR-016) |
| VI. Cross-Domain Visibility | Overview must draw from all 5 domains; Accounts section must be top-level | ✅ Must reflect |
| VII. Repair When Safe | Manual-only issues must not show Apply; repairable issues must show diff preview | ✅ Must reflect (FR-015, FR-016) |

**Gate result**: ✅ No violations. Proceed.

## Project Structure

### Documentation (this feature)

```text
specs/001-prototype-prd-alignment/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command)
```

### Source Code (prototype)

```text
prototype/
├── app.js       # NAV array, state, all view render functions (~3,160 lines as of Round 5)
├── styles.css   # All styles; new component classes added here (~1,100 lines)
├── index.html   # Shell structure: sidebar, toolbar, main, inspector aside
├── data.js      # Mock data constants (DATA object, ~740 lines)
└── store.js     # Persistence layer — localStorage hydrate/save/reset/isDirty (added Round 5)
```

*(Round 5 added `store.js` as a fifth source file and `prototype/README.md` as the reviewer process guide. The original Round 1 constraint "No new files" applied only to that round.)*

---

## Phase 0: Research

### Resolved decisions

All NEEDS CLARIFICATION items resolved before tasking. No external research required — all
decisions are made from the spec, PRD, and existing prototype code.

**Decision 1: Inspector slide-over mechanism**
- **Decision**: Use CSS `transform: translateX(100%)` → `translateX(0)` with a fixed-position
  `<aside>` overlay. The `<main>` element does NOT change width. A semi-transparent backdrop
  div receives click-to-close.
- **Rationale**: Matches PRD spec (slide-over, not pushing content). Simplest CSS-only approach.
- **Alternative rejected**: Persistent split column (current state — violates FR-005/FR-006).

**Decision 2: Onboarding flow placement**
- **Decision**: Add `onboarding` as a top-level pseudo-view reachable via a "Show onboarding"
  button in Settings → Workspace. The view renders as a full-width centered modal-style card
  grid showing all 7 iCloud states as distinct cards. It does not replace the app shell.
- **Rationale**: The spec allows "a dedicated view navigable from Settings." This avoids
  complicating the nav structure with a transient flow.
- **Alternative rejected**: Modal overlay triggered on load (hard to review individually);
  standalone route outside nav (requires app entry point changes).

**Decision 3: Sync pill states**
- **Decision**: The existing `.sync-pill` in the sidebar footer is promoted to a toolbar-level
  element (moved to `#toolbar`). It cycles through 4 states via a `data-state` attribute:
  `synced`, `syncing`, `stale`, `error`. A toggle button in Settings → Workspace lets reviewers
  cycle states for design review.
- **Rationale**: Toolbar placement matches the macOS app spec. The data-attribute pattern is
  already used elsewhere in the prototype.

**Decision 4: Benchmark heat map** *(superseded by FR-022 correction, Round 5)*
- **Original decision**: Replace the `lineChart` call in `viewInvestmentsBenchmarks()` with a new
  `heatMapTable()` function. Each row = one investment account + one S&P 500 row. Each of
  8 columns = one time period (D, W, M, 3M, 6M, 1Y, 3Y, 5Y). Cells show % return; positive
  values get a green shade, negative a red shade via CSS class.
- **Round 5 correction**: The heat map is a **view toggle on the Holdings screen**, not a separate
  Benchmarks screen. Toggle state stored in `state.holdingsMode` (`'standard'` | `'heatmap'`). The
  `/investments-benchmarks` route is a legacy redirect to `investments-holdings` (FR-071). The
  `heatMapTable()` helper still exists but is called from within the Holdings view on toggle.

**Decision 5: FR-021 gap**
- The spec numbers functional requirements FR-001 through FR-025 but skips FR-021. This is
  confirmed as an intentional numbering artifact — no missing requirement.

---

## Phase 1: Design & Contracts

### Data model

See [data-model.md](data-model.md) for entity specifications.

### Interface contracts

See [contracts/nav-structure.md](contracts/nav-structure.md) for the canonical NAV array
contract and view ID registry.

### Quickstart

See [quickstart.md](quickstart.md) for how to open and review the prototype.

---

## Complexity Tracking

> No constitution violations. Table not required.
