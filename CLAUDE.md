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
| `docs/PRD.md` | Primary direction doc. Module requirements, data model, IA. Has a Changelog section at bottom. |
| `docs/technical design.md` | Architecture, layered system model, workspace folder structure, all 24 CSV file specs, service responsibilities, validation rules. |
| `docs/roadmap-v1.md` | Phased implementation roadmap with Product/Design/Dev tasks per phase and milestone gates. |
| `.specify/memory/constitution.md` | 7 non-negotiable principles governing all implementation decisions. Read this before proposing any architectural change. |
| `docs/_reviews/` | Prototype feedback and domain research. `round-N.md` = UX review. `prd-update-plan.md` and `technical-design-update-plan.md` = applied change lists. |

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
  Investments/      accounts.csv (investment-specific), holdings.csv, transactions.csv,
                    prices.csv, sleeves.csv, sleeve-targets.csv, benchmarks/sp500.csv
  Business/         entities.csv, transactions/{entity-slug}-YYYY-MM.csv,
                    categories.csv, budgets.csv
  Taxes/            deductions.csv, estimated-payments.csv, settings.csv, archive/
  Notes/            monthly/, strategy/
  .finance-meta/    manifest.json, schemas/, backups/, logs/
```

Full column-level specs for all 24 CSV file types are in `docs/technical design.md §8`.

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

## Doc update workflow

The PRD and technical design are living documents updated after each prototype review round:

1. Add `docs/_reviews/round-N.md` with prototype/UX feedback
2. Synthesize into `docs/_reviews/prd-update-plan.md` (section-by-section change list)
3. Apply changes to `docs/PRD.md` with a Changelog entry at the bottom
4. Apply cascading changes to `docs/technical design.md` with its own Changelog entry
5. If principles changed, amend `.specify/memory/constitution.md` with a version bump
6. Commit all affected docs together

## Open architectural decisions

These are unresolved as of 2026-06-08 and must be decided before Phase 1 build starts
(documented in `docs/technical design.md §21`):

- Master accounts registry model: two-file (`Accounts/accounts.csv` + `Investments/accounts.csv` linked by `account_id`) vs unified file with optional fields
- Deductions file structure: one `deductions.csv` (all types via `deduction_type` column) vs per-type files
- Tax year-close trigger: explicit in-app action, automatic rollover, or both
- Right detail pane: globally closed by default, or section-specific exceptions allowed
