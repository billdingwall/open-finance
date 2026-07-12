# Implementation Plan: Delete Inside the Edit Modal (UV-2)

**Branch**: `010-reorder-and-delete` *(shared with UV-1)* | **Date**: 2026-07-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/011-delete-in-edit-modal/spec.md`

## Summary

Add a destructive **Delete** action to the edit forms for accounts, account groups, and
categories (the locked R5 "delete inside the edit flow" convention). The action is a new **entry
point only**: it closes the form and calls the existing, tested `requestDelete` pipeline —
reference scan → reassignment picker → atomic delete+reassignment plan → standard write preview —
guaranteeing zero divergence from the detail-pane delete (SC-002) by calling the same function.
No Kit changes, no schema changes, no new AppState storage; one one-line DESIGN.md amendment.

## Technical Context

**Language/Version**: Swift 6, macOS 15 deployment target, Xcode 16 toolchain
**Primary Dependencies**: SwiftUI (existing form/sheet machinery); no new dependencies
**Storage**: No file-format changes — deletes flow through the existing `WritePlan`/`WriteService` path
**Testing**: Swift Testing via CI (`swift test` needs full Xcode); CLT box builds only
**Target Platform**: macOS 15+ desktop app
**Project Type**: Desktop app — App-layer-only change (`Sources/FinanceWorkspaceApp/`)
**Performance Goals**: None new — the delete pipeline's existing behavior/budgets apply
**Constraints**: Full preview-before-apply retained (the v1.1.2 direct-manipulation carve-out explicitly excludes destructive flows); scope = exactly 3 entity types; add-mode shows no Delete
**Scale/Scope**: ~1 view file + 1 AppState helper + 1 test file + 1 DESIGN.md line

## Constitution Check

*GATE: evaluated pre-Phase-0 and re-evaluated post-Phase-1 design — PASS, no violations.*

| Principle | Status | Evidence |
|---|---|---|
| I. Plain Files First | ✅ | No format changes; a delete removes one row via the standard diff machinery. |
| II. Read Model Second | ✅ | Post-delete re-index re-derives every projection; no cached state survives. |
| III. Native Over Generic | ✅ | System destructive button role; standard sheet sequencing; keyboard-reachable footer. |
| IV. Safe Writes Only | ✅ | Full preview-before-apply retained (carve-out inapplicable); backup + atomic apply + gate + drift via the unchanged `WriteService`; referenced deletes resolve by explicit user choice. |
| V. Traceability Always | ✅ | The preview names the target file + row; the reassignment picker lists every referencing row. |
| VI. Cross-Domain Visibility | ✅ | Reference scanning spans collections via the shared context (unchanged `ReferenceScanner`). |
| VII. Repair When Safe | ✅ | Not touched. |
| File & Schema Conventions | ✅ | No schema change. |
| V1 Scope Boundaries | ✅ | No deferred-scope feature touched. |

**Post-Phase-1 re-check (2026-07-11, incl. clarify session)**: design artifacts and the FR-008
clarification (nearest-valid post-delete navigation — existing `AppRouter.resolve` behavior,
principle III) introduce no violations. Complexity Tracking: empty — no deviations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/011-delete-in-edit-modal/
├── plan.md                          # This file
├── research.md                      # Phase 0 — R1…R4
├── data-model.md                    # Phase 1 — "no data changes" + inherited invariants
├── quickstart.md                    # Phase 1 — verification walkthrough
├── contracts/delete-in-edit-form.md # UI behavioral contract
├── checklists/requirements.md       # Spec quality checklist (passed)
└── tasks.md                         # Phase 2 — /speckit-tasks output (not created here)
```

### Source Code (repository root)

```text
DESIGN.md                             # DA-011-1: modal-form row gains the destructive-action
                                      # placement note (+ Changelog) — gates the UI task

Sources/FinanceWorkspaceApp/
├── AppState+WriteFlows.swift         # + requestDeleteFromEditForm(context:): close form →
│                                     #   runloop hop → requestDelete(SourceRef(path, rowRef))
│                                     #   (mirrors finishEditForm's sheet sequencing)
└── UI/Write/EntityEditForms.swift    # footer gains the leading Delete button: shown iff
                                      #   !context.isNew && path ∈ {accounts, account-groups,
                                      #   categories}; role .destructive + err tint +
                                      #   SecondaryButtonStyle; disabled+reason while gated

Tests/FinanceWorkspaceAppTests/
└── DeleteInEditFormTests.swift       # entry-point parity with detail-pane path (SC-002),
                                      # whitelist + add-mode suppression, cancel byte-identity,
                                      # gate refusal, and FR-008: deleting the currently-routed
                                      # entity resolves the route to the nearest valid context
```

**Structure Decision**: App-layer only. The Kit's delete machinery (`ReferenceScanner`,
`WritePlanBuilder.delete`, `WriteService`) is reused without modification — research R1.

**FR-008 (post-delete navigation, clarified 2026-07-11)**: no new code expected —
`AppState.reindex()` already runs `route = AppRouter.resolve(route, in: snapshot)` after every
write, which drops stale entity selections to the nearest valid context (shipped in 008). The
requirement is covered by **asserting** this behavior in `DeleteInEditFormTests` (delete the
currently-routed account → route resolves to its group / All accounts), not by new plumbing. If
the assertion exposes a gap in `AppRouter.resolve`'s fallback for a specific route shape, fix it
there — one function, already unit-tested.

## Doc amendments (explicit task — carry into tasks.md)

1. **DA-011-1 (gates the UI task)** — `DESIGN.md` `modal-form` component row + Changelog: add the
   destructive-action placement note (leading in the footer, separated from Cancel/Save,
   system destructive role + `err` token, secondary chrome, gate-disabled with reason). No new
   tokens; clear `/design-adherence` before touching `EntityEditForms.swift`.

## Complexity Tracking

> No violations — table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *(none)* | | |
