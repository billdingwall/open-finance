# Implementation Plan: Manual Re-ordering of Accounts & Account Groups (UV-1)

**Branch**: `010-reorder-and-delete` | **Date**: 2026-07-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/010-reorder-and-delete/spec.md`

## Summary

Let users drag-reorder account groups (and accounts within a group) in the sidebar, persisting
the arrangement as an optional, additive `sort_order` column on `Accounts/account-groups.csv` /
`Accounts/accounts.csv` via the existing safe-write machinery (backup + atomic apply + write
gate, **no preview sheet** — clarified). Ordering is applied once at the `WorkspaceContext`
typed-accessor layer so every surface (sidebar, card grids, pickers, dropdowns) inherits the
same canonical order. Absent values fall back to today's ID-sorted default. Four guiding-doc
amendments (DA-001…DA-004, from the spec) ship with the feature; DESIGN.md gains the
drag-reorder pattern **before** any UI work.

## Technical Context

**Language/Version**: Swift 6, macOS 15 (Sequoia) deployment target, Xcode 16 toolchain
**Primary Dependencies**: SwiftUI (`List`/`ForEach.onMove`, context menus), SwiftPM module layout; no new dependencies
**Storage**: Plain CSV in the iCloud/local workspace — `Accounts/accounts.csv`, `Accounts/account-groups.csv` (+ bundled JSON schemas in `Sources/FinanceWorkspaceKit/Resources/Schemas/`)
**Testing**: Swift Testing via `swift test` (macOS CI; CLT-only machines build + run executables only)
**Target Platform**: macOS 15+ desktop app (SwiftPM executable now; XcodeGen app target for signed builds)
**Project Type**: Desktop app — library (`FinanceWorkspaceKit`) + SwiftUI app (`FinanceWorkspaceApp`) + CLIs
**Performance Goals**: Visible reorder < 100ms after drop; safe write completes ≤ 1s on a typical workspace (SC-001, clarified 2026-07-10)
**Constraints**: Additive/non-breaking file change (no `schema_version` bump, no migration); untouched workspaces stay byte-identical; reorder writes fully gated on sync state; no modal preview for the drag flow (clarified 2026-07-09)
**Scale/Scope**: Dozens of groups/accounts per workspace (small-N sorting; no perf risk beyond the write path)

## Constitution Check

*GATE: evaluated pre-Phase-0 and re-evaluated post-Phase-1 design — PASS with one documented
tension (see Complexity Tracking).*

| Principle | Status | Evidence |
|---|---|---|
| I. Plain Files First | ✅ | Order lives in the CSVs as a human-editable integer column; hand edits are honored (contract `sort-order-column.md`); no hidden store, no device-local ordering. |
| II. Read Model Second | ✅ | Order is re-derived from files on every scan; the optimistic UI order is provisional and rolled back if the write fails (research R6); deleting/reinstalling the app reproduces the order from files alone. |
| III. Native Over Generic | ✅ | Native `List`/`ForEach.onMove` drag with system drop indicators; context-menu Move up/down for full keyboard/VoiceOver access (research R4). |
| IV. Safe Writes Only | ⚠️ justified | Backup + atomic apply + WriteGate + drift detection all reused unchanged via `WritePlan`/`WriteService`. Deviation: no preview *UI* before apply — clarified product decision (Session 2026-07-09); the drag's live feedback is the preview. See Complexity Tracking. |
| V. Traceability Always | ✅ | Reorder writes are ordinary `WritePlan`s (intent `.edit`) targeting a named file with row diffs; backups are timestamped; the rows remain traceable in inspectors as today. |
| VI. Cross-Domain Visibility | ✅ | Master-registry files gain the column; ordering applied at the shared accessor layer feeds all domains identically (research R3). |
| VII. Repair When Safe | ✅ | No new repair class; invalid values degrade at the normalizer with a warning (research R7) — no speculative repair. |
| File & Schema Conventions | ✅ | Optional column ⇒ explicitly "not breaking": `schema_version` stays 1, no migration executable (research R1). |
| V1 Scope Boundaries | ✅ | No deferred-scope feature touched; no new module. |

**Post-Phase-1 re-check (2026-07-10)**: design artifacts introduce no new violations; the single
Principle IV tension is unchanged and documented below.

## Project Structure

### Documentation (this feature)

```text
specs/010-reorder-and-delete/
├── plan.md                          # This file
├── research.md                      # Phase 0 — R1…R7 decisions
├── data-model.md                    # Phase 1 — schema + Swift model changes
├── quickstart.md                    # Phase 1 — verification walkthrough
├── contracts/
│   ├── sort-order-column.md         # CSV column contract (external tools)
│   └── reorder-interaction.md       # Sidebar UI behavioral contract
├── checklists/requirements.md       # Spec quality checklist (passed)
└── tasks.md                         # Phase 2 — /speckit-tasks output (not created here)
```

### Source Code (repository root)

```text
Sources/FinanceWorkspaceKit/
├── Resources/Schemas/
│   ├── accounts.schema.json          # + sort_order (optional integer)
│   └── account-groups.schema.json    # + sort_order (optional integer)
├── Domain/Accounts/
│   ├── AccountModels.swift           # Account.sortOrder, AccountGroup.sortOrder (Int?)
│   └── AccountEngine.swift           # preserve accessor order (drop keys.sorted()/ids.sorted())
├── Domain/Mapping/RecordMappers.swift # map sort_order; sort accessors by composite key (choke point)
└── Persistence/Write/                # REUSED UNCHANGED: WritePlan, WriteService, BackupService, WriteGate

Sources/FinanceWorkspaceApp/
├── AppState+WriteFlows.swift         # (or sibling AppState+Reorder.swift) applyReorder entry point:
│                                     #   optimistic order → WritePlanBuilder.edit → WriteService.apply
│                                     #   → rollback on refusal → projection refresh
└── UI/Shell/NavigationSidebarView.swift  # nested ForEach (groups → accounts), .onMove, .moveDisabled,
                                          # context-menu Move up/down

Tests/
├── FinanceWorkspaceKitTests/         # mapper/accessor ordering, plan shape, degradation, round-trip
│   └── Perf/PerformanceHarness.swift # reorder-write ≤ 1s budget
└── FinanceWorkspaceAppTests/         # applyReorder: optimistic apply, gate rollback, refresh

docs/  (DA tasks from the spec — ship with the feature)
├── architecture/containers-and-budgets.md  # DA-001: §3.21 + §3.14 sort_order rows
├── product-requirements.md                 # DA-002: user-defined ordering section + Changelog
├── product-roadmap.md                      # DA-003: UV-1/UV-2 → Readying table
DESIGN.md                                   # DA-004: drag-reorder pattern + Changelog — BEFORE UI tasks
```

**Structure Decision**: existing two-target layout (Kit + App) untouched; the feature adds no
module, no service, and reuses the Phase-1 safe-write primitives without modification. The only
new code surface is one `AppState` entry point and the sidebar restructure.

## Doc amendments (explicit tasks — carried from spec "Doc Amendments Required")

`/speckit-tasks` MUST emit these as first-class tasks with the stated ordering constraint:

1. **DA-004 (FIRST, gates all UI tasks)** — DESIGN.md: add the list/drag-reorder pattern (drag
   affordance, drop indicator, context-menu Move up/down fallback, 80–120ms motion tier,
   disabled-while-gated treatment) + Changelog entry; clear `/design-adherence` before
   `NavigationSidebarView` work.
2. **DA-001** — `docs/architecture/containers-and-budgets.md`: add `sort_order | integer |
   Optional — display ordering` to §3.21 accounts.csv and §3.14 account-groups.csv (mirror the
   §3.3 categories wording).
3. **DA-002** — `docs/product-requirements.md`: add the manual-ordering concept (+ Changelog).
4. **DA-003** — `docs/product-roadmap.md`: promote UV-1/UV-2 into Growth → Readying with
   branch/spec `010-reorder-and-delete`; on merge move to Delivered + close backlog rows.

## Complexity Tracking

> Constitution Check has one justified tension.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Principle IV "preview before apply" — reorder writes skip the preview sheet (backup, atomicity, gating, drift detection retained) | Direct manipulation: a modal preview per drag makes rearranging unusable; the drag's live drop indicator + immediate visible result *is* the change preview; clarified with the PM (spec Clarifications, Session 2026-07-09) | Showing the standard preview sheet per drag — rejected in clarification: multi-step rearranging becomes a modal gauntlet; risk is already bounded (single-column diffs, timestamped backup, re-drag reverts). **Interpretation, not amendment**: the write flow still "shows the affected rows" — live in the list — before the user releases the drop. `/speckit-analyze` should treat this row as the sanctioned justification. |
