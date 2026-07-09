# open-finance

A native macOS personal finance workspace backed by plain CSV and Markdown files in iCloud Drive.

The app is a structured interface over files the user owns — not a database, not a sync service. It
parses, validates, and projects finance data into dashboards for budgeting, savings, investments,
business accounting, and tax prep.

**Status:** In build. Phases 1–4 (Foundation → Domain layers) are complete and merged; **Phase 5
(Presentation Layer) is build-complete** on `006-presentation-layer` — the app is now fully
navigable (read-only; write flows are Phase 6). See "Running the app" below and
`docs/test-plans.md` for what's testable today.

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
| Build | Swift Package Manager (`Package.swift`); macOS app target via XcodeGen (`App/project.yml`) |
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
swift run fixture-generate    --workspace ~/Finance-Dev --months 12   # sample data
open ~/Finance-Dev/Finance                                 # browse the files in Finder

open prototype/index.html                                  # review the intended UI/UX
```

## Running the app

The app is DEBUG-built with the **local-folder provider** — it reads the workspace at
`~/Finance-Dev/Finance` (no iCloud, no signing needed). Provision that workspace first (above).

**Option A — desktop launcher (no Xcode needed).** Build a double-clickable app bundle:

```bash
./scripts/build-app.sh          # produces "Finance Workspace.app" in the repo root
open "Finance Workspace.app"    # …or just double-click it in Finder
```

`Finance Workspace.app` is a convenience launcher for local testing: it's the DEBUG build,
ad-hoc signed, with the generic macOS app icon, and it's gitignored. **Re-run
`scripts/build-app.sh` after any code change** to refresh it. Drag it to the Dock or
`/Applications` if you want it to stick around. (First launch may need a right-click → **Open**
if macOS Gatekeeper prompts.)

**Option B — quick run, no bundle.** `swift run FinanceWorkspaceApp` launches the same binary
directly (it has no Dock icon this way — ⌘-Tab to the window).

**Option C — the real Xcode app** (needs full **Xcode 16**, not just Command Line Tools). This
is the signed/entitled target that gets iCloud and, eventually, a designed icon and notarization
(Phase 7):

```bash
brew install xcodegen                                      # once
cd App && xcodegen generate --spec project.yml && open FinanceWorkspace.xcodeproj
# then Run (⌘R) in Xcode
```

Full manual test flows: `docs/test-plans.md`. Build/run detail: `docs/_notes/running-and-testing.md`.

---

## Repository structure

```
open-finance/
├── Package.swift              # SwiftPM manifest
├── Sources/
│   ├── FinanceWorkspaceKit/   # Library: Platform, Parsing, Validation, Domain, Persistence, Migration
│   ├── FinanceWorkspaceApp/   # SwiftUI app — DesignSystem + UI/ (shell + all module views)
│   └── <clis>/                # bootstrap-workspace, validate-workspace, repair-workspace, migrate-r6, …
├── App/                       # XcodeGen spec for the signed macOS app target (project.yml)
├── scripts/build-app.sh       # Build the local "Finance Workspace.app" launcher (no Xcode needed)
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
| `docs/product-backlog.md` | Prioritized product backlog (user value / security & performance / visual design / under-consideration). |
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
