# open-finance

A native macOS personal finance workspace backed by plain CSV and Markdown files in iCloud Drive.

The app is a structured interface over files the user owns — not a database, not a sync service. It
parses, validates, and projects finance data into dashboards for budgeting, savings, investments,
business accounting, and tax prep.

**Status:** In build. Phase 1 (Foundation) and Phase 2 (Parsing, Validation & Infrastructure) are
complete and merged; Phase 3 (Domain Layer I) is next. There is no usable app UI yet — the current
build is a library + CLIs + a diagnostic shell. See `docs/test-plans.md` for what's testable today.

---

## What it is

- **File-first:** CSV and Markdown in iCloud Drive are the source of truth — no proprietary database.
- **macOS native:** SwiftUI, three-column `NavigationSplitView`, keyboard navigation, Finder-compatible.
- **Traceable:** every KPI links to a detail view; every detail row links to a source file and row.
- **Safe writes:** structured edits are validated, previewable, and backed up before applying.

## Modules (v1)

| Module | Purpose |
|---|---|
| Overview | KPI dashboard across all domains |
| Accounts | Income, expense, asset, and liability management per account |
| Budget | Monthly plan-vs-actual, category and group totals |
| Savings & Investments | Savings goals; portfolios, sleeves, assets; benchmark comparisons |
| Taxes | Estimated payments, realized gains, tax-adjustment tracking, prep checklist |

Business activity is a `group_type = business` account group (not a separate module). Notes, Issues,
and Files views are deferred to V2.

---

## Tech stack

| Area | Choice |
|---|---|
| Language | Swift 6 |
| Build | Swift Package Manager (`Package.swift`) — no Xcode project yet |
| App | SwiftUI · macOS 15 (Sequoia)+ · iCloud Drive |
| Library | `FinanceWorkspaceKit` (Platform, Parsing, Validation, Domain, Persistence, Migration) |
| Prototype | Static HTML/CSS/JS + Chart.js (no build step) |
| CI | GitHub Actions — SwiftLint (Linux) + `swift build`/`swift test` (macOS) |

## Getting started

**Prerequisites:** macOS 15+, a Swift 6 toolchain (`swift --version`). Full **Xcode 16** is only
needed to run `swift test` (a Command-Line-Tools-only machine can build and run the CLIs).

```bash
swift build                                                # build everything

# Provision a local workspace of CSV/MD files and inspect it
swift run bootstrap-workspace --workspace ~/Finance-Dev/Finance
swift run validate-workspace  --workspace ~/Finance-Dev/Finance
open ~/Finance-Dev/Finance                                 # browse the files in Finder

swift run FinanceWorkspaceApp                              # diagnostic shell (DEBUG → local folder, no iCloud)
open prototype/index.html                                  # review the intended UI/UX
```

Full manual test flows: `docs/test-plans.md`. Build/run detail: `docs/_notes/running-and-testing.md`.

---

## Repository structure

```
open-finance/
├── Package.swift              # SwiftPM manifest
├── Sources/
│   ├── FinanceWorkspaceKit/   # Library: Platform, Parsing, Validation, Domain, Persistence, Migration
│   ├── FinanceWorkspaceApp/   # SwiftUI app (diagnostic shell today; full UI in Phase 5)
│   └── <clis>/                # bootstrap-workspace, validate-workspace, repair-workspace, migrate-r6, …
├── Tests/                     # Swift Testing suite
├── prototype/                 # Static HTML/CSS/JS prototype — design & flow reference
├── docs/                      # Product, architecture, roadmap, and process docs (see below)
├── specs/                     # Spec Kit feature artifacts (NNN-feature-name)
├── workspace-template/        # Seed files for a new Finance workspace
├── .specify/                  # Spec Kit workflow engine, templates, constitution
├── .claude/skills/            # Agent skills — Spec Kit + design
├── DESIGN.md                  # Design system
├── CLAUDE.md                  # AI operating instructions
└── README.md
```

## Documentation map

| Doc | What it answers |
|---|---|
| `DESIGN.md` | The design system — tokens, components, rules. |
| `docs/product-requirements.md` | What & why — goals, user stories, requirements, IA. |
| `docs/technical-design.md` → `docs/architecture/` | How & where — architecture, workspace layout, CSV/MD specs, validation, pipelines. |
| `docs/product-roadmap.md` | Phased plan and milestone gates. |
| `docs/project-management.md` | Planned `[FIX]`/`[DECIDE]` backlog. |
| `docs/out-of-scope-followups.md` | Items deferred during spec implementation. |
| `docs/test-plans.md` | App testability status + manual user flows. |
| `CLAUDE.md` | How AI agents (and contributors) work in this repo. |

---

## Workspace file structure

The app reads a `Finance/` folder in iCloud Drive:

```
Finance/
├── Workspace.md
├── .finance-meta/   # App-managed: manifest, schemas, backups, logs
├── Accounts/        # Master registry, account-groups, liabilities, unified transaction ledger
├── Budget/          # Categories, budgets, allocations
├── Savings/         # Goals, progress snapshots
├── Investments/     # Assets, prices, portfolios, sleeves, benchmarks
├── Taxes/           # Tax-adjustments, estimates, documents, estimated payments, settings, archive
└── Notes/           # Monthly reviews and strategy notes
```

Personal and business activity share the unified `Accounts/transactions/` ledger (distinguished by
`account_group_id` and a `BX-` ID prefix). Full column-level specs:
`docs/architecture/containers-and-budgets.md §3`.

---

## How we work

Features are built with **Spec Kit** (`/speckit-specify` → `clarify` → `plan` → `tasks` →
`implement`) on `NNN-feature-name` branches. Product docs evolve in a round-numbered refinement loop
driven by prototype reviews. Full process and conventions are in `CLAUDE.md`.
