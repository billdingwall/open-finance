# CLAUDE.md

AI operating instructions for this repository: build/test commands, conventions, the design gate,
and the Spec Kit + doc workflows. **This file is "how to work in the code," not the architecture
reference** — architecture and product specs live under `docs/` (see Key documents).

## Project status

**Project phase: 🌱 GROWTH** (entered 2026-07-09). The MVP (v1, roadmap Phases 1–8) is
code-complete; forward work flows **`docs/product-backlog.md` → the roadmap's Growth/Readying
table → spec-driven delivery** (one `NNN-` branch per promoted item). Implementation residue goes
straight into the backlog.

**Live project and spec state is tracked in Claude's persistent project memory** (auto-loaded each
session; the repo-root `MEMORY.md` was retired 2026-07-03). Canonical records stay in the repo:
the Growth pipeline + MVP delivery record in `docs/product-roadmap.md`, the prioritized backlog in
`docs/product-backlog.md`, feature artifacts in `specs/NNN-*/`, history in git. The active feature
is named in the Spec Kit block below.

The app is a **Swift Package** (`Package.swift`), not a hand-authored `.xcodeproj` — the build
environment is Command-Line-Tools-only. The XcodeGen app target (`App/project.yml`) carries the
iCloud entitlement and builds unsigned in CI; the first signed release is backlog SP-8.

## Build & test

```bash
swift build                                                    # build library, app, and CLIs
swift test                                                     # Swift Testing — needs full Xcode (runs in macOS CI)
swift run bootstrap-workspace --workspace ~/Finance-Dev/Finance        # provision a workspace
swift run fixture-generate    --workspace ~/Finance-Dev --months 12    # dev fixture data
swift run index-check         --workspace ~/Finance-Dev/Finance        # scan + print index summary
swift run validate-workspace  --workspace ~/Finance-Dev/Finance        # parse + validate (exit 1 on errors)
swift run repair-workspace    --workspace ~/Finance-Dev/Finance --dry-run   # preview auto-repairs (--apply to perform)
swift run migrate-r6          --workspace ~/Finance-Dev/Finance --dry-run   # preview pre-R6 migration
swift run accounts-overview   --workspace ~/Finance-Dev/Finance --as-of 2026-06-30   # AccountEngine projection
swift run budget-overview     --workspace ~/Finance-Dev/Finance --period 2026-06     # BudgetEngine projection
swift run overview-dashboard  --workspace ~/Finance-Dev/Finance --as-of 2026-06-30   # OverviewEngine dashboard (5 live cards)
swift run savings-overview    --workspace ~/Finance-Dev/Finance --as-of 2026-06-30   # SavingsGoalEngine projection
swift run portfolio-overview  --workspace ~/Finance-Dev/Finance --as-of 2026-06-30   # PortfolioEngine holdings + sleeve drift
swift run benchmark-overview  --workspace ~/Finance-Dev/Finance --as-of 2026-06-30   # BenchmarkEngine heat map
swift run tax-overview        --workspace ~/Finance-Dev/Finance --tax-year 2026       # TaxEngine + deductions/estimate/prep
swift run tax-overview        --workspace ~/Finance-Dev/Finance --tax-year 2026 --seed-standard --apply  # safe write: seed standard adjustment
swift run tax-overview        --workspace ~/Finance-Dev/Finance --tax-year 2025 --close-year --apply     # safe write: year-close archive
swift run FinanceWorkspaceApp                                  # diagnostic shell (DEBUG → local-folder provider)
```

**Testing protocol:** `swift test` requires a full Xcode toolchain; a CLT-only machine can
`swift build` and run the executables but not `swift test`. Both run in CI.

## Conventions

- **Swift 6**, macOS 15 (Sequoia) deployment target, Xcode 16 toolchain.
- **Lint must pass `swiftlint --strict`** before pushing (CI enforces it). Install locally with
  `brew install swiftlint`.
- Match surrounding code: SwiftPM module layout under
  `Sources/FinanceWorkspaceKit/{Platform,Parsing,Validation,Domain,Persistence,Migration}/`.
- Reuse the Phase 1 safe-write primitives (`BackupService`/`FileCoordinatorService`/`WriteGate`) for
  any write — never reimplement safe-write logic.
- **Commit/push only when asked.** Default branch is `main`; feature work goes on `NNN-feature-name`
  branches.

## Interacting with the codebase

- **Build order rule:** `AccountEngine` + `Accounts/accounts.csv` is the master account registry that
  every other domain references via `account_id`. Build it before other domain engines.
- Don't reopen locked decisions — see `docs/technical-design.md §21`. To change one, update §21 and
  the affected docs together.
- Architecture, workspace file layout, CSV/MD specs, and validation rules: **read, don't restate** —
  they live in `docs/architecture/` (see `docs/architecture/index.md`).

## CI

- `.github/workflows/swiftlint.yml` — SwiftLint (Linux runner).
- `.github/workflows/ci-macos.yml` — `swift build` / `swift test` (macOS runner).

## Design system (NON-NEGOTIABLE)

`DESIGN.md` (repo root) is the single source of design truth. **Before proposing or making ANY
UI/UX/frontend change** — SwiftUI views, `prototype/` HTML/CSS/JS, colors, typography, spacing,
layout, components, charts, icons, motion, navigation — you **MUST**:

1. **Read `DESIGN.md`** (front-matter tokens + body rules), and
2. **Clear the `design-adherence` gate** (`/design-adherence`): confirm the change uses semantic
   tokens, respects the Do's & Don'ts, and stays native-macOS-first.

If a change needs something `DESIGN.md` doesn't cover, **update `DESIGN.md` first** (with a Changelog
entry). Never improvise design values in code; never let `DESIGN.md`, `prototype/styles.css`, the
SwiftUI tokens, and Figma drift apart.

**Design skills** (`.claude/skills/`): `design-adherence` (mandatory gate), `swiftui-view-scaffold`,
`design-token-sync`, `chart-styling`, `figma-css-sync`. Default tools once Phase 5 UI work begins.

## Constitution (enforce on every change)

Verify no change violates these (canonical: `.specify/memory/constitution.md`):

1. **Plain files first** — CSV/Markdown canonical; no hidden database.
2. **Read model second** — projections are derived and regenerable from files.
3. **Native over generic** — `NavigationSplitView`, keyboard nav, Finder-compatible.
4. **Safe writes only** — timestamped backup + atomic apply + preview.
5. **Traceability always** — every KPI → detail; every detail row → source file + row.
6. **Cross-domain visibility** — shared master account registry; `LinkingEngine` connects domains.
7. **Repair when safe** — only deterministic, previewable, user-confirmed repairs.

## V1 scope boundaries

**Do not implement or design for** (deferred to V2): Notes viewer, Issues standalone view, Files
explorer, Budget rules/automation, bank/brokerage sync, multi-workspace, AI analysis.

## Spec Kit workflow

Features are built with Spec Kit, in order:

```
/speckit-specify   /speckit-clarify   /speckit-plan   /speckit-tasks   /speckit-implement
```

Branches: `NNN-feature-name` (via `/speckit-git-feature`).

**Growth-phase entry point**: a new feature starts by **promoting a backlog item** — move its row
into the roadmap's *Growth → Readying* table (amending PRD/TDD first if the item is
under-consideration), then run the Spec Kit chain on a fresh `NNN-` branch. On merge, update the
roadmap's *Delivered* table and close the backlog row.

<!-- SPECKIT START -->
**Active feature**: `010-reorder-and-delete` (branch carries both promoted items). **UV-1**
(sidebar re-ordering): implementation **complete 2026-07-10** — 25/26 tasks
(`specs/010-reorder-and-delete/`); open: the Flow 11 manual drag pass (`docs/test-plans.md`) +
CI confirmation. **UV-2** (delete in edit modals): spec + plan complete 2026-07-11
(`specs/011-delete-in-edit-modal/plan.md` — entry-point-only reuse of the `requestDelete`
pipeline; DA-011-1 DESIGN.md modal-form note gates the UI task). **Previous**:
`008-polish-launch` complete 2026-07-09 (PRs #22/#23). **Next**: `/speckit-tasks` →
`/speckit-implement` for UV-2, then the branch PR closing both backlog rows.
<!-- SPECKIT END -->

### On spec completion — maintain the living docs

Before closing out any implemented spec:
- **`docs/product-backlog.md`** — add any items in the spec's scope that were skipped/deferred
  during implementation **directly to the backlog** (Source column = source spec + task for
  provenance). There is no separate follow-ups doc — residue is backlog work like anything else.
- **`docs/test-plans.md`** — update the app testability status and user-flow list for what the spec
  now makes testable (or still blocks).

## Doc update workflow (product refinement loop)

Project docs are living, updated per refinement round (detail: `docs/_notes/workflow-overview.md`):

1. Add `docs/_refinement/r{n}-review.md` (UX/feedback or a direction note); `{n}` = next global round.
2. Synthesize into `docs/_refinement/r{n}-update-{doc}.md` per affected doc.
3. Apply to `docs/product-requirements.md` (+ Changelog).
4. Cascade to `docs/technical-design.md` and `docs/product-roadmap.md` (+ Changelogs); update the
   relevant `docs/architecture/` file directly for spec details; update `docs/product-backlog.md`.
5. If principles changed, amend `.specify/memory/constitution.md` (version bump).
6. Update `docs/_design/` and `prototype/`, then start the next round.
7. Commit all affected docs together.

## Key documents

| Document | Purpose |
|---|---|
| *(persistent memory)* | **Read first** — active state (phase, next steps, blockers) lives in Claude's project memory, auto-loaded each session. Not a repo file. |
| `DESIGN.md` | Design system (tokens, components, rules). Read before any UI/UX/frontend change. |
| `docs/product-requirements.md` | What & why — modules, scenarios, data model, IA. |
| `docs/technical-design.md` | Architecture overview + locked decisions (§21); links to `docs/architecture/`. |
| `docs/architecture/` | Canonical specs: entities, workspace layout, all CSV/MD specs, validation rules, pipelines. |
| `docs/product-roadmap.md` | **Growth pipeline** (Readying/Delivered tables + promotion process) above the **MVP delivery record** (Phases 1–8, historical). |
| `docs/product-backlog.md` | Prioritized product backlog (user value → security & performance ∥ visual design; under-consideration at bottom). Replaced `docs/project-management.md` 2026-07-07. |
| `docs/test-plans.md` | App testability status + manual user flows. |
| `.specify/memory/constitution.md` | The 7 non-negotiable principles. |
| `prototype/` | Static prototype — design/flow reference for the SwiftUI build. |
