# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

Phase 1 (Foundation & Architecture, spec `002-foundation-architecture`) is **complete and merged to `main`** (PR #15). **Phase 2 (Parsing, Validation & Infrastructure) is now active** on branch `003-parsing-validation` — spec `specs/003-parsing-validation/`. The app is scaffolded as a **Swift Package** (`Package.swift`), not a hand-authored `.xcodeproj` — the build environment is Command-Line-Tools-only (no Xcode GUI / `xcodegen`), so SwiftPM keeps the foundation buildable and CI-friendly. An Xcode app target + iCloud entitlements are added when UI/packaging/signing is needed (later phase). Architecture module folders map to `Sources/FinanceWorkspaceKit/{Platform,Domain,Validation,Persistence,Parsing}/`.

Phase 1 delivered (all four user stories): platform + domain models, `CloudStorageProvider`/`LocalFolderProvider`/`ICloudContainerService`, file-safety primitives (`BackupService`, `FileCoordinatorService`, `WriteGate`), US1 provisioning (`WorkspaceProvisioner`/`WorkspaceManager`), US2 file index (`FileIndexService`/`FileWatcherService`/`ManifestStore`), US3 sync-state/conflict logic (`SyncStateMapper`/`ConflictResolver`), US4 dev-env + CI. The only deferred Phase 1 task is the iCloud ubiquity-container entitlement (T004 — needs the Xcode app target). See `specs/002-foundation-architecture/tasks.md` for the full record.

### Build & test

```bash
swift build                 # build all targets (library, app, scripts)
swift test                  # run the suite (Swift Testing) — needs full Xcode; runs in macOS CI
swift run bootstrap-workspace --workspace <path>/Finance   # provision a workspace
swift run fixture-generate  --workspace ~/Finance-Dev --months 12   # dev fixture data
swift run index-check       --workspace ~/Finance-Dev/Finance       # scan + print index summary
```

> Note: `swift test` requires a full Xcode toolchain (XCTest/Swift Testing); a CLT-only machine can `swift build` and run the executables but not `swift test`. CI: `.github/workflows/swiftlint.yml` (SwiftLint on a Linux runner) + `.github/workflows/ci-macos.yml` (`swift build`/`swift test` on a macOS runner). The macOS build/test CI landed in Phase 1 — earlier docs that say "full Mac build CI deferred to Phase 5" are superseded.

## What this project is

A native macOS personal finance workspace (SwiftUI, iCloud-backed) that uses CSV and Markdown files as the source of truth. The app is an interface *over* files the user owns — not a database, not a sync service. It parses, validates, and projects finance data into views for budgeting, savings, investments, business accounting, and tax prep.

## Key documents — read these before making changes

| Document | Purpose |
|---|---|
| `docs/product-requirements.md` | What & why: primary product direction — modules, user scenarios, data model, IA. Has a Changelog section at bottom. |
| `docs/technical-design.md` | How & where: lean overview file linking to `docs/architecture/` for detail. Covers architecture summary, workspace layout, and locked decisions (§21). |
| `docs/architecture/` | Full technical specs extracted from `technical-design.md` in Round 7. Four files: `core-domain.md` (entities, module layout, services), `containers-and-budgets.md` (workspace structure + all 28 CSV/MD specs), `rulesets-and-taxes.md` (validation rules + UI requirements), `data-pipelines.md` (read/write/repair flows, scripts, ingestion diagrams). See `docs/architecture/index.md` for a quick-lookup table. |
| `docs/product-roadmap.md` | When: phased implementation roadmap with Product/Design/Dev tasks per phase and milestone gates. |
| `docs/project-management.md` | Tasks: remaining work needed before the Phase 1 build begins. Updated each round to retire resolved items and add new FIX/DECIDE items. |
| `.specify/memory/constitution.md` | 7 non-negotiable principles governing all implementation decisions. Read this before proposing any architectural change. |
| `docs/_refinement/` | Review rounds and update plans, named **round-first** so they group by round. `r{n}-review.md` = raw team feedback (or user-direction note). `r{n}-update-{doc}.md` = formatted doc update plan based on that round. Round numbers are global across all docs (one round = one revision event). |
| `docs/_notes/` | Loose notes and domain research for team reference (e.g. `account-types.md`, `deduction-types.md`, `workflow-overview.md`). |
| `docs/_design/` | Design mocks, icons, images, design system. |
| `prototype/` | Static prototype used to review and refine the app experience before implementing changes. |

## Architecture — the layer model

The app uses a strict five-layer architecture. Each layer only depends on layers below it.

```
File layer        WorkspaceManager, ICloudContainerService, FileIndexService, FileWatcherService
Parsing layer     CSVParserService, CSVSchemaRegistry, MarkdownParserService, ValidationEngine
Domain layer      AccountEngine, BudgetEngine, SavingsGoalEngine, PortfolioEngine,
                  BenchmarkEngine, BusinessEngine, TaxEngine, TaxPrepEngine, TaxAdjustmentEngine,
                  LinkingEngine, OverviewEngine
Projection layer  Cross-domain projections: OverviewSummaryCard, AccountSummaryCard,
                  TaxAdjustmentSummary, BenchmarkPeriod heat map, etc.
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
  Accounts/         accounts.csv, account-groups.csv, liabilities.csv, account-rules.csv,
                    transactions/YYYY-MM.csv  (unified ledger; business rows prefixed BX-)
  Budget/           categories.csv, budgets.csv, budget-allocations.csv,
                    savings-goal-contributions.csv
  Savings/          goals.csv, progress.csv
  Investments/      assets.csv, prices.csv, dividends.csv, tax-lots.csv, portfolios.csv,
                    sleeves.csv, sleeve-targets.csv, benchmarks/sp500.csv
  Taxes/            tax-adjustments.csv, estimates.csv, documents.csv,
                    estimated-payments.csv, settings.csv, archive/
  Notes/            monthly/, strategy/
  .finance-meta/    manifest.json, schemas/, backups/, logs/
```

There is no separate `Personal/` or `Business/` folder — personal and business activity share the unified `Accounts/transactions/` ledger, distinguished by `account_group_id` and a `BX-` ID prefix. Full column-level specs for all CSV file types are in `docs/architecture/containers-and-budgets.md §3`.

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

## Development toolchain

**Primary AI dev assistant**: Claude Code (this file provides Claude Code context). Build/test commands and a session-start hook will be added here once the Xcode project is created in Phase 1.

**Primary IDE**: Google Antigravity 2.0 / Antigravity IDE. Xcode remains required as the macOS build toolchain — Antigravity is the code editing environment but does not replace Xcode for building and running SwiftUI apps. IDE-specific project settings must not conflict with Xcode project settings.

**Design-to-code bridge**: [figma-cli](https://github.com/silships/figma-cli) — a local CLI that lets Claude Code design directly in Figma Desktop using natural language. Communicates with Figma Desktop via CDP (no API key, no rate limits). Install in Yolo mode (default) during Phase 1 setup — Claude Code handles installation. Design tokens export to `docs/_design/tokens/` (DTCG/W3C format); icons and SVG assets export to `docs/_design/icons/`. Claude Code reads design specs live from Figma Desktop during implementation phases.

**Secondary IDEs (later phases)**: VS Code and Kiro are candidates for later development phases. No setup required until needed.

**Platform requirements:**
- macOS deployment target: **macOS 15 (Sequoia)**. Update to the latest stable release at Phase 1 build start if newer.
- Xcode: **Xcode 16**. Update to latest stable at Phase 1 build start.
- Swift: **Swift 6**.
- CI/CD: GitHub Actions. SwiftLint on a standard Linux runner in Phase 1; full Mac build CI deferred to Phase 5.

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

<!-- SPECKIT START -->
**Active feature**: `003-parsing-validation` (Phase 2 — Parsing, Validation & Infrastructure)
Spec: `specs/003-parsing-validation/spec.md`
Previous: `002-foundation-architecture` (Phase 1) — complete, merged to `main` (PR #15)
<!-- SPECKIT END -->

## Doc update workflow (product refinement loop)

The project-level docs are living documents updated after each prototype review round
(full workflow detail in `docs/_notes/workflow-overview.md`):

1. Add `docs/_refinement/r{n}-review.md` with prototype/UX feedback (or, for a user-direction revision, a short direction note). `{n}` is the next global round number, continuing the sequence already in the doc changelogs.
2. Synthesize into `docs/_refinement/r{n}-update-{doc}.md` per affected document (section-by-section change list, e.g. `r4-update-product-requirements.md`)
3. Apply changes to `docs/product-requirements.md` with a Changelog entry at the bottom
4. Apply cascading changes to `docs/technical-design.md` with its own Changelog entry, then to `docs/product-roadmap.md`. When spec details (CSV schemas, validation rules, service responsibilities, UI requirements) are affected, update the relevant file in `docs/architecture/` directly — `technical-design.md` links to those files rather than duplicating their content. Also update `docs/project-management.md` to retire resolved FIX items and add any new FIX/DECIDE items.
5. If principles changed, amend `.specify/memory/constitution.md` with a version bump
6. Update `docs/_design/` assets and `prototype/` to reflect the changes, then start the next review round
7. Commit all affected docs together

## Architectural decisions

All Phase 1 architectural decisions were locked as of 2026-06-10. The full locked-decision
record is in `docs/technical-design.md §21`; remaining pre-build work is tracked in
`docs/project-management.md`. Key locked decisions:

- Master accounts registry: unified file — `Accounts/accounts.csv` covers all account types (investment metadata as optional columns); `Investments/accounts.csv` removed
- Tax adjustments file (Round 6, supersedes the old deductions decision): one `Taxes/tax-adjustments.csv` with all types via the `adjustment_type` column; Tax-adjustment is a first-class object
- Tax year-close: explicit in-app "Close Tax Year" action, no automatic rollover
- Right detail pane: globally closed by default, no section-specific exceptions

Round 6 (2026-06-23) object-model decisions (see `docs/technical-design.md §21`): storage names aligned to object names (`entities.csv`→`account-groups.csv` / `entity_id`→`account_group_id`, `holdings.csv`→`assets.csv` / `holding_id`→`asset_id`, `deductions.csv`→`tax-adjustments.csv`); Liability is a first-class object (`Accounts/liabilities.csv`); Portfolio is the investment container (`Investments/portfolios.csv`); multi-entry transactions use a shared `group_id`; investment trades fold into the unified ledger.

Do not reopen locked decisions without updating `docs/technical-design.md §21` and the affected docs together.
