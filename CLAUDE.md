# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

Pre-build. This repository currently contains design and planning documents only — no Swift source code exists yet. The Xcode project (`FinanceWorkspaceApp`) will be created in Phase 1 of the roadmap.

When the Swift project exists, build/test commands will be added here. Until then, work in this repo means reading, authoring, and updating documents.

## What this project is

A native macOS personal finance workspace (SwiftUI, iCloud-backed) that uses CSV and Markdown files as the source of truth. The app is an interface *over* files the user owns — not a database, not a sync service. It parses, validates, and projects finance data into views for budgeting, savings, investments, business accounting, and tax prep.

## Key documents — read these before making changes

| Document | Purpose |
|---|---|
| `docs/product-requirements.md` | What & why: primary product direction — modules, user scenarios, data model, IA. Has a Changelog section at bottom. |
| `docs/technical-design.md` | How & where: architecture, layered system model, workspace folder structure, all 24 CSV file specs, service responsibilities, validation rules. |
| `docs/product-roadmap.md` | When: phased implementation roadmap with Product/Design/Dev tasks per phase and milestone gates. |
| `docs/project-management.md` | Tasks: remaining work needed before the Phase 1 build begins. |
| `.specify/memory/constitution.md` | 7 non-negotiable principles governing all implementation decisions. Read this before proposing any architectural change. |
| `docs/_refinement/` | Review rounds and update plans. `review-r{n}.md` = raw team feedback. `update-{doc}-r{n}.md` = formatted doc update plan based on a review. |
| `docs/_notes/` | Loose notes and domain research for team reference (e.g. `account-types.md`, `deduction-types.md`, `workflow-overview.md`). |
| `docs/_design/` | Design mocks, icons, images, design system. |
| `prototype/` | Static prototype used to review and refine the app experience before implementing changes. |

## Architecture — the layer model

The app uses a strict five-layer architecture. Each layer only depends on layers below it.

```
File layer        WorkspaceManager, ICloudContainerService, FileIndexService, FileWatcherService
Parsing layer     CSVParserService, CSVSchemaRegistry, MarkdownParserService, ValidationEngine
Domain layer      AccountEngine, BudgetEngine, SavingsGoalEngine, PortfolioEngine,
                  BenchmarkEngine, BusinessEngine, TaxEngine, TaxPrepEngine, DeductionEngine,
                  LinkingEngine, OverviewEngine
Projection layer  Cross-domain projections: OverviewSummaryCard, AccountSummaryCard,
                  TaxDeductionSummary, BenchmarkPeriod heat map, etc.
Presentation      SwiftUI views in UI/ — one folder per module
```

**The critical dependency**: `AccountEngine` and `Accounts/accounts.csv` is the master account registry. Every transaction file in every other domain references `account_id` from it. Build this before other domain engines.

## Module structure (planned)

```
FinanceWorkspaceApp/
  App/            AppState, AppRouter, scene setup
  Platform/       Workspace and iCloud services, file indexing, backup
  Parsing/        CSV and Markdown parsers, schema registry, normalizer
  Domain/         One subfolder per domain engine (Accounts, Budget, Savings,
                  Investments, Business, Taxes, CrossDomain)
  Validation/     ValidationEngine, RuleCatalog, RepairService
  Persistence/    ManifestStore, SettingsStore
  UI/             One subfolder per module view + Shared components
  Scripts/        Developer CLI scripts (bootstrap, validate, repair, import, export)
```

## Workspace file structure (iCloud)

The Finance folder in iCloud Drive is the source of truth:

```
Finance/
  Accounts/         accounts.csv, account-rules.csv
  Personal/         transactions/YYYY-MM.csv, categories.csv, budgets.csv
  Savings/          goals.csv, progress.csv
  Investments/      holdings.csv, transactions.csv, prices.csv, sleeves.csv,
                    sleeve-targets.csv, benchmarks/sp500.csv
  Business/         entities.csv, transactions/{entity-slug}-YYYY-MM.csv,
                    categories.csv, budgets.csv
  Taxes/            deductions.csv, estimated-payments.csv, settings.csv, archive/
  Notes/            monthly/, strategy/
  .finance-meta/    manifest.json, schemas/, backups/, logs/
```

Full column-level specs for all 24 CSV file types are in `docs/technical-design.md §8`.

## Constitution principles (non-negotiable)

Before proposing any implementation detail, verify it doesn't violate these:

1. **Plain files first** — CSV and Markdown remain canonical. No hidden database.
2. **Read model second** — Projections are derived and always regenerable from files.
3. **Native over generic** — macOS `NavigationSplitView`, keyboard nav, Finder-compatible.
4. **Safe writes only** — Every write needs a timestamped backup, atomic apply, and preview.
5. **Traceability always** — Every KPI links to a detail view; every detail row links to a source file and row.
6. **Cross-domain visibility** — All modules share the master account registry; `LinkingEngine` connects domains.
7. **Repair when safe** — Only deterministic, previewable, user-confirmed repairs.

## V1 scope boundaries

**Deferred to V2** (do not implement, do not design for): Notes viewer, Issues standalone view, Files explorer, Budget rules/automation, bank/brokerage sync, multi-workspace, AI analysis.

## Spec Kit workflow

Features are developed using the Spec Kit workflow. Commands in order:

```
/speckit-specify    Create or update a feature spec
/speckit-clarify    Identify underspecified areas in the spec
/speckit-plan       Generate implementation plan and design artifacts
/speckit-tasks      Generate dependency-ordered task list
/speckit-implement  Execute tasks from tasks.md
```

Feature branches follow the `NNN-feature-name` naming convention (created by `/speckit-git-feature`).

## Doc update workflow (product refinement loop)

The project-level docs are living documents updated after each prototype review round
(full workflow detail in `docs/_notes/workflow-overview.md`):

1. Add `docs/_refinement/review-r{n}.md` with prototype/UX feedback
2. Synthesize into `docs/_refinement/update-{doc}-r{n}.md` per affected document (section-by-section change list, e.g. `update-product-requirements-r1.md`)
3. Apply changes to `docs/product-requirements.md` with a Changelog entry at the bottom
4. Apply cascading changes to `docs/technical-design.md` with its own Changelog entry, then to `docs/product-roadmap.md`
5. If principles changed, amend `.specify/memory/constitution.md` with a version bump
6. Update `docs/_design/` assets and `prototype/` to reflect the changes, then start the next review round
7. Commit all affected docs together

## Architectural decisions

All Phase 1 architectural decisions were locked as of 2026-06-10. The full locked-decision
record is in `docs/technical-design.md §21`; remaining pre-build work is tracked in
`docs/project-management.md`. Key locked decisions:

- Master accounts registry: unified file — `Accounts/accounts.csv` covers all account types (investment metadata as optional columns); `Investments/accounts.csv` removed
- Deductions file structure: one `Taxes/deductions.csv` with all types via `deduction_type` column
- Tax year-close: explicit in-app "Close Tax Year" action, no automatic rollover
- Right detail pane: globally closed by default, no section-specific exceptions

Do not reopen locked decisions without updating `docs/technical-design.md §21` and the affected docs together.
