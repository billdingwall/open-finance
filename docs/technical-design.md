
---

# Personal Finance Workspace for macOS
## Technical Design Document

> **Round 7 note:** Sections 6–8 (workspace structure and file specs) and 10–16 (data model,
> architecture, service responsibilities, flows, validation, UI requirements) have been extracted
> to `docs/architecture/` to keep this file reviewable. This document remains the authoritative
> overview, locked-decisions record, and changelog. See `docs/architecture/index.md` for a
> navigation guide to the detailed files.

## 1. Purpose

This document translates the product requirements into implementation and design requirements for a native macOS application that uses CSV and Markdown files stored in iCloud Drive as the source of truth.

The app is not the owner of the data model in the database sense. Instead, it discovers files, validates them, normalizes them into internal read models, and presents personal budgeting, savings goals, portfolio management, small business finance, and tax workflows through a structured interface.

## 2. Design goals

### Primary goals

- Keep CSV and Markdown as canonical storage.
- Make the app a trustworthy interface over plain files.
- Support personal, portfolio, business, and tax workflows in one connected workspace.
- Provide safe structured writes, file repair, and source traceability.
- Keep the architecture modular enough for rapid prototyping and later automation.
- Design the storage layer behind a provider protocol so that iCloud, Google Drive, Dropbox, and local-folder modes can be added as independent backends in V2 without changing the parsing or domain layers.

### Non-goals

- No hidden primary database in v1.
- No bank sync or brokerage sync in v1.
- No tax filing engine in v1.
- No AI-driven financial analysis in v1.

## 3. System overview

The system should use a **plain-files source of truth** plus an **internal normalized read model**. The app reads CSV and Markdown from an iCloud-backed workspace, parses and validates them, builds domain models, and then derives projections for dashboards, tables, reports, and inspectors.

### Core architecture layers

1. **Storage layer**
   iCloud workspace resolution, file access, file coordination, backups, sync state.

2. **Indexing layer**
   File scan, file manifest, change detection, sync hints, hash tracking.

3. **Parsing layer**
   CSV parsing, Markdown front matter parsing, schema detection, validation results.

4. **Domain layer**
   Accounts, budget, savings, investments, business, tax, notes, and cross-domain linking.

5. **Projection layer**
   Overview cards, monthly summaries, benchmark comparisons, issue dashboards, drill-down views.

6. **Presentation layer**
   SwiftUI views, inspectors, forms, tables, contextual filters, charts, and commands.

## 4. Information architecture

The app should use a three-column `NavigationSplitView` layout, but the left panel should be dedicated to navigation rather than shared with filters. `NavigationSplitView` is intended for two- or three-column interfaces where selections in leading columns control presentations in later columns, which aligns well with a finance workspace that needs stable navigation and deep drill-down views. [web:64]

This layout also fits a macOS productivity workflow because the navigation model can stay stable while filters, tables, and detail views change with the currently selected context. SwiftUI's document-based app patterns and Observation-based state model support this kind of multi-pane structure with state that updates predictably as selections change. [web:22][web:33][web:34]

### Primary navigation

The left sidebar is the primary navigation surface for the app. It should contain stable top-level sections and allow nested links for specific entities, accounts, goals, sleeves, reports, and saved views.

Top-level navigation (v1):
- Accounts
- Budget
- Savings & Investments
- Taxes
- Settings

The Overview dashboard is the **default screen** on launch. It is reached via the sidebar header (the workspace title, displayed as "Finance Dashboard"), not a dedicated nav item.

Deferred to V2:
- Notes
- Issues
- Files

### Left sidebar structure

The left sidebar is static and should only support expandable groups under the relevant top-level section when specified. The sidebar is for navigation only, not for temporary or view-specific filters.

Examples:
- **Accounts**
  - Overview
  - Account groups (user-customizable, loaded from `Accounts/account-groups.csv`):
    - Personal Accounts (Personal)
    - Place of Employment (Employment)
    - Consulting LLC (Business)
    - Freelance (Business)
    - Rental LLC (Business)
- **Budget**
  - Overview
  - Budget history
  - Categories
- **Savings & Investments**
  - Overview
  - Goals
  - Portfolio
- **Taxes**
  - Current tax year
  - Prep checklist
  - Tax archive
- **Notes** *(V2)*
  - Monthly reviews
  - Strategy notes
  - Business notes
  - Tax notes
- **Issues** *(V2)*
  - All issues
  - Repairable
  - Manual review

The Account groups group under Accounts is the primary example of data-driven nested links — items are populated from `Accounts/account-groups.csv` rather than hardcoded. (The account-facing term is "group", not "entity"; the model-level rename `entities.csv`→`account-groups.csv` / `entity_id`→`account_group_id` was applied in Round 6 — see `docs/_refinement/r6-update-technical-design.md`.) The local "New group" action creates a new account group. Other sections may add group- or item-specific links under their parent section using the same pattern. These data-driven links are part of the fixed sidebar structure, not view-specific filters.

### App shell

#### Left sidebar

Primary navigation only:
- Top-level domains
- Nested entity links
- Nested note groups

#### Main panel

The center panel becomes the primary working area for the currently selected navigation item. It should contain the contextual header and the main content view.

Main-panel structure:
1. **Context header**
   - Selected view title, with the **local actions row on the same line as the title, right-aligned** within the main column
   - Breadcrumb or parent context

2. **Content surface**
   - Table
   - Card grid
   - Chart area
   - Summary rows
   - List view
   - Empty state
   - Validation state

Module screens have **no general filter bar** in v1; the contextual filter surface (period/date/account/group/sleeve/goal/category/severity/search/saved-view selectors) is deferred to V2. A screen shows period or account selection inline only where it is intrinsic to that screen.

Sync status and issue status are global: they live in the **top header** (issue-count chip immediately left of the sync-status chip), not in the per-view context header.

The **Overview dashboard has no filters**. It is a fixed read-only dashboard and is the default landing screen.

#### Right detail pane

The right pane is the detail and inspector surface. It is **collapsible and closed by default**. It opens as a slide-over rather than a persistent split, so it does not compete with the main content surface when not in use. Pane width should be fixed or lightly constrained.

It should show the selected row, summary, note, file preview, source lineage, validation details, or repair preview.

Supported detail surfaces:
- Inspector
- Source file preview
- Source row details
- Markdown note preview
- Validation issue details
- Repair preview
- Edit form

### Navigation behavior

- Top-level navigation changes the active domain.
- Nested links change the selected group or scoped view within that domain.
- The sidebar should preserve expansion state for nested groups.
- The right panel should update based on selection, not navigation alone.
- Deep links should be representable as domain plus nested group or account selection. (A general filter-state surface is deferred to V2.)
- The app should support keyboard navigation across sidebar, main panel, and detail inspector.

### Global interaction patterns

- Every KPI links to a filtered detail table in the main panel.
- Every detail row links to a source file and source row in the right panel.
- Every source file can be opened externally in Finder or the default editor.
- Every repair action requires preview and confirmation.
- Every write flow shows target file, rows affected, and backup behavior.

## 5. Workspace and iCloud model

### Workspace strategy

Support two workspace modes:
1. **Default v1 mode:** app-owned iCloud ubiquity container.
2. **Advanced mode:** user-selected iCloud Drive folder. *(V2 — see §21)*

Recommendation: implement app-owned container first because Apple's ubiquity container pathing is more predictable and is the native document-store model for app-managed files.

### Storage provider abstraction

In v1 the only supported backend is iCloud via the app-owned ubiquity container. The storage layer must be built around a `CloudStorageProvider` protocol so that alternative backends — Google Drive, Dropbox, local folder — can be added in V2 without restructuring workspace management, parsing, or domain logic.

`ICloudContainerService` is the v1 conforming implementation. `WorkspaceManager` resolves the workspace URL through the active provider rather than calling iCloud APIs directly.

In **DEBUG builds the default `CloudStorageProvider` is a local-folder provider** rooted at `~/Finance-Dev/` (populated by the `fixture-generate` script). Live iCloud is exercised only in Release/TestFlight builds. This keeps the development loop free of entitlement and signing round-trips and lets workspace resolution run on CI. Dev-data isolation happens at the provider layer, not via a separate iCloud container.

Minimum protocol surface:
```swift
protocol CloudStorageProvider {
    var syncState: SyncState { get }
    var isAvailable: Bool { get }
    func resolveWorkspaceURL() async throws -> URL
}
```

Providers planned for V2:
- Google Drive (via Drive File Stream or Files API)
- Dropbox (via Dropbox SDK)
- Local folder (for users who manage sync externally)

### Workspace resolution

Primary path pattern:
```swift
FileManager.default
  .url(forUbiquityContainerIdentifier: "iCloud.com.<org>.OpenFinance")?
  .appendingPathComponent("Documents")
  .appendingPathComponent("Finance")
```

The container identifier must be the reverse-DNS, `iCloud.`-prefixed form (e.g.
`iCloud.com.<org>.OpenFinance`) — **not** the bare string `OpenFinance`, which resolves
to `nil` at runtime. This exact string is what populates the
`com.apple.developer.ubiquity-container-identifiers` entitlement array in the Xcode
project. One container identifier is used across both development and distribution
(iCloud Documents storage has no dev/prod split).

### Sync considerations

iCloud availability may vary by account state and entitlement setup, and container access can fail or return nil when configuration or account state is wrong. The app must surface this explicitly instead of assuming the workspace is always available.

Per-file sync state is sourced from **`NSMetadataQuery`** (scope
`NSMetadataQueryUbiquitousDocumentsScope`) — its per-item attributes
(`NSMetadataUbiquitousItemDownloadingStatusKey`, percent-downloaded,
upload/download-in-progress, and conflict flags) yield the seven states directly,
rather than being hand-tracked.

Required sync states and their UI treatment:

| State | UI treatment | Writes |
|---|---|---|
| Available | No indicator (subtle green header sync chip) | Enabled |
| Not signed into iCloud | Full-screen blocking onboarding + offer local-folder fallback | — |
| Container unavailable | Full-screen blocking + diagnostics + retry | — |
| Syncing (workspace) | Persistent header chip "Syncing…" | Disabled (sync-first write gate) |
| Local copy stale | Per-file row indicator + dismissible banner | Gated per-file |
| File missing locally (placeholder) | Per-file indicator + download affordance (`startDownloadingUbiquitousItem`) | Gated |
| Conflict detected | Banner + per-file indicator → resolution surface | Gated |

### Conflict resolution (v1)

v1 does **not** auto-merge. When iCloud reports an unresolved conflict, the app
surfaces `NSFileVersion.unresolvedConflictVersions` with a "Keep mine / Keep iCloud /
Keep both" choice. Finance files are never silently merged.

## 6. Workspace folder structure

→ Full folder tree and folder design rules: [`docs/architecture/containers-and-budgets.md §1`](architecture/containers-and-budgets.md#1-workspace-folder-structure)

## 7. File classification rules

→ Classification rules for CSV and Markdown files: [`docs/architecture/containers-and-budgets.md §2`](architecture/containers-and-budgets.md#2-file-classification-rules)

## 8. File specifications

→ All CSV and Markdown file specifications (§3.1 – §3.28): [`docs/architecture/containers-and-budgets.md §3`](architecture/containers-and-budgets.md#3-file-specifications)

## 9. Metadata model

Each file should have machine-readable metadata at one of three levels:
- path metadata
- filename metadata
- in-file metadata

### Required metadata attributes

| Attribute | Applies to | Purpose |
|---|---|---|
| schema_version | CSV, Markdown | Validation and migration. Increment on any breaking change. Stored as a **leading comment row** `# schema_version: N` (line 1 of every managed CSV); `CSVParserService` tolerates and strips leading `#` comment lines. If absent, the registry's current version is assumed and the file is flagged for repair. (Accepted tradeoff: Numbers/Excel render the comment as a junk first row.) |
| domain | All | accounts, budget, savings, investments, taxes, notes (plus `meta` for the root `Workspace.md` descriptor). The app-managed `.finance-meta/` subtree is **excluded from the file index**. Note: `business` is **not** a domain — business activity lives in the `Accounts/` tree as a `group_type`. |
| subtype | All | transactions, goals, note, budget, prices, etc. |
| period | Monthly files | Time grouping |
| account_group_id | Account-group-scoped files | Account-group ownership (was `entity_id`) |
| account_id | Account-specific files | Source scoping |
| account_group | Account files, transaction files | Group-level classification for account type routing |
| created_at | Markdown preferred | Audit trail |
| updated_at | Optional | UI freshness |
| source | Optional | Imported origin |

### Schema version migration policy

A **breaking change** is any modification to a CSV column or Markdown front matter field that is currently in use — including: renaming a column, removing a column, changing a column's type or enum values, or adding a required column to an existing file type.

Adding a new optional column is **not** a breaking change.

When a breaking change is introduced:
- The `schema_version` integer in that file type's schema definition is incremented.
- A migration script is supplied as part of the release that introduces the change.
- Migration scripts live in `Scripts/` and follow the naming convention `migrate-{file-type}-v{old}-to-v{new}.swift`.
- The `RepairService` detects version mismatches during validation and prompts the user to run the applicable migration script. It does not auto-migrate breaking changes.
- After migration, the `schema_version` header value in the affected CSV files is updated to the new version.

### App-managed manifest

Path:
`~/Library/Application Support/OpenFinance/<workspace_id>/manifest.json`

The manifest is a **device-local, regenerable cache** kept *out* of the synced iCloud
container so it cannot conflict or go stale across machines (two Macs index on
independent schedules). A missing or corrupt manifest triggers a rescan — never data
loss. This is consistent with the Constitution (files are canonical; the read model is
regenerable). With the manifest moved out, `.finance-meta/` in iCloud carries only
`schemas/`, `backups/`, and `logs/`.

Purpose:
- current workspace snapshot
- file discovery cache
- file classification results
- hash and modified-date tracking
- last validation results summary

Suggested shape:
```json
{
  "manifest_schema_version": 1,
  "app_version": "1.0.0",
  "workspace_id": "finance-main",
  "last_indexed_at": "2026-05-10T11:00:00Z",
  "files": [
    {
      "path": "Accounts/transactions/2026-05.csv",
      "domain": "accounts",
      "subtype": "transactions",
      "schema_version": 1,
      "hash": "sha256:...",
      "modified_at": "2026-05-10T10:55:00Z",
      "byte_size": 18244,
      "row_count": 142,
      "last_indexed_at": "2026-05-10T11:00:00Z",
      "validation_status": "warning"
    }
  ]
}
```

Per-file **sync state** is *not* stored here — it is volatile and owned by the OS
(`NSMetadataQuery`), held in memory. **Repair history** is not stored here either — it
lives in `.finance-meta/logs/repair-log.csv`.

## 10. Internal data model

→ Canonical and cross-domain entities: [`docs/architecture/core-domain.md §1`](architecture/core-domain.md#1-internal-data-model)

## 11. Application architecture

→ Recommended stack and module layout: [`docs/architecture/core-domain.md §2`](architecture/core-domain.md#2-application-architecture)

## 12. Service responsibilities

→ Service contracts for all platform and domain services: [`docs/architecture/core-domain.md §3`](architecture/core-domain.md#3-service-responsibilities)

## 13. Read, write, and repair flows

→ Full flow descriptions including the structured write flow and delete-reference-check: [`docs/architecture/data-pipelines.md §1`](architecture/data-pipelines.md#1-read-write-and-repair-flows)

## 14. Scripts and developer tooling

→ Required and optional developer scripts: [`docs/architecture/data-pipelines.md §2`](architecture/data-pipelines.md#2-scripts-and-developer-tooling)

## 15. Validation rules

→ File-level, cross-file, domain, repairable, and manual-only validation rules: [`docs/architecture/rulesets-and-taxes.md §1`](architecture/rulesets-and-taxes.md#1-validation-rules)

## 16. UI requirements by section

→ Per-section UI specs (Overview, Accounts, Budget, S&I, Taxes, Notes, Issues): [`docs/architecture/rulesets-and-taxes.md §2`](architecture/rulesets-and-taxes.md#2-ui-requirements-by-section)

## 17. Commands and menus

Recommended macOS commands:
- New Workspace
- Open Workspace
- Reindex Workspace
- Validate Workspace
- Repair Selected Issue
- Open Source File
- Reveal in Finder
- Export Current View
- Toggle Inspector
- Open Backup Folder

## 18. Performance and caching

- Keep canonical data in files, not in a hidden DB.
- Maintain an in-memory projection cache for UI speed.
- Optionally persist non-authoritative cache artifacts in the device-local manifest (`~/Library/Application Support/OpenFinance/<workspace_id>/manifest.json`), kept out of the synced container (§9).
- Re-scan incrementally based on hash and modified date.
- Debounce watcher-triggered refreshes.

## 19. Security and safety

- Do not mutate files silently.
- Do not auto-apply repairs without preview.
- Backup before every write or repair.
- Track every repair in `.finance-meta/logs/repair-log.csv`.
- Mark app-generated files clearly in front matter or seed comments.

## 20. Rapid prototype order

1. Workspace bootstrap and indexing
2. CSV and Markdown parsing
3. Overview projections (default landing dashboard, no filters, issues table inline; issues chip in the global header)
4. Accounts module (master registry, account-group screens with individual-account cards and inline ledger — no sub-tabs, dedicated per-account screen, account rules)
5. Budget module (pie chart overview, category management, 3-month trailing averages)
6. Savings & Investments (flat goal list; holdings-focal portfolio with heat-map toggle and sleeve table)
7. Business group reporting
8. Tax module (consolidated current-year view with payments, gains/income, and deductions inline; per-account rates; full-width prep checklist screen; archive)
9. Structured write flows
10. Repair workflows
11. Notes viewer *(V2)*
12. Issues management view *(V2)*

Rationale for order: Accounts is built before other modules because personal, business, and investment transaction files all reference `account_id` from the master registry. Having it early keeps subsequent module builds cleaner.

## 21. Decisions to lock before build

### Locked by PRD

These decisions are settled and should not be reopened for v1:

- **App-owned iCloud container first** ✓ — single workspace, app-owned ubiquity container
- **Single workspace first** ✓
- **Strict canonical CSV schemas first** ✓
- **Deterministic repair only** ✓ — no speculative or guided migration flows in v1
- **Notes deferred to V2** ✓
- **Issues standalone view deferred to V2** ✓ — issues surfaced in Overview table
- **Budget rules and automation deferred post-MVP** ✓
- **Benchmark import manual in v1** ✓

### Locked — 2026-06-10

- **CloudStorageProvider protocol surface** ✓ — Minimum surface confirmed: `resolveWorkspaceURL() async throws -> URL`, observable `syncState`, `isAvailable: Bool`. The protocol exposes the storage connection status for display in the app settings. Sync-conflict resolution is iCloud-specific and stays on `ICloudContainerService`, not on the protocol.

- **Accounts master registry — unified file** ✓ — `Accounts/accounts.csv` is the single master registry for all account types including investment accounts. Investment-specific metadata (tax treatment, performance tracking) is stored as optional columns in the master file. `Investments/accounts.csv` (spec §8.7) is removed. Budget, Savings & Investments, and Taxes modules use the master registry as their base and add domain-specific views and calculations on top.

- **Savings/ and Investments/ folder separation** ✓ — Keep as separate folders at the file level. The UI presents them as a unified module; the file layer keeps them separate.

- **Deductions → Tax-adjustments file** ✓ — *(Superseded in Round 6.)* The former single `Taxes/deductions.csv` / `deduction_type` is renamed to `Taxes/tax-adjustments.csv` / `adjustment_type`, with the union enum `standard, above_the_line, itemized, business-expense, credit, liability` (`schedule_c` → `business-expense`). Tax-adjustment is now a first-class object that can link to a transaction, category, asset, liability, account, or account-group. See the Round 6 lock block below.

- **Tax year-close trigger — explicit in-app action** ✓ — Tax archive files are written only when the user explicitly triggers "Close Tax Year" in the app. No automatic rollover in v1.

- **Right panel default state — global closed** ✓ — Right pane is closed by default across all sections. It opens when the user interacts with content in the main panel (selection, KPI tap, row inspection). No section-specific auto-open exceptions in v1.

- **iCloud container identifier** ✓ — Container is identified by the reverse-DNS,
  `iCloud.`-prefixed form `iCloud.com.<org>.OpenFinance` (corrected in Round 8 — the
  bare `OpenFinance` value resolves to `nil` at runtime). One identifier across dev
  and distribution.

- **Workspace bootstrap seed accounts** ✓ — On first launch, bootstrap seeds six starter accounts in `Accounts/accounts.csv`: personal bank account, personal credit card, business bank account, business credit card, savings account, and investment account.

### Locked — 2026-06-10 (Phase 2)

- **Amount sign convention** ✓ — Negative = debit (money out), positive = credit (money in). Applies consistently across all transaction file types. The `direction` column is retained alongside the sign for import mapping readability. The `CSVNormalizer` flips signs from source files that use the opposite convention during import.

- **`schema_version` migration policy** ✓ — A breaking change is any modification to a CSV column or Markdown front matter field currently in use (rename, remove, type change, enum change, or new required column). Adding an optional column is not breaking. Breaking changes increment `schema_version` and require a migration script (`Scripts/migrate-{file-type}-v{old}-to-v{new}.swift`) shipped with the release. The `RepairService` detects version mismatches and prompts the user to run the script; it does not auto-migrate breaking changes.

### Locked — 2026-06-23 (Round 6 — object model)

- **Storage names aligned to object names** ✓ — `entities.csv`→`account-groups.csv` (`entity_id`→`account_group_id`, `entity_type`→`group_type`), `holdings.csv`→`assets.csv` (`holding_id`→`asset_id`, `market_value`→`current_value`), `deductions.csv`→`tax-adjustments.csv` (`deduction_id`→`tax_adjustment_id`, `deduction_type`→`adjustment_type`). These are breaking renames; a one-time, preview-able migration script performs them and bumps `schema_version`.
- **Liability is a first-class object** ✓ — New `Accounts/liabilities.csv` (peer of Asset). An account can hold both an asset and a liability (e.g. a mortgage account holds the property and the loan). Debt fields live on Liability, not as columns on Account. Reverses the earlier "fold debt into account columns" idea.
- **Portfolio is the investment container** ✓ — New `Investments/portfolios.csv`; sleeves re-parent under `portfolio_id`. Adopted instead of the r5-audit "Strategy" container. Group nesting (`parent_group_id`) is **not** adopted in v1.
- **Multi-entry transactions** ✓ — A shared `group_id` (with `group_role`) links the rows of a transfer or paycheck split; `group_id` is a connector, not a primary key. Transfers net to zero; gross/net splits reconcile `net = gross − Σ(withholding)`.
- **Investment trades fold into the unified ledger** ✓ — Recorded as `type = trade` rows in `Accounts/transactions/YYYY-MM.csv`; `Investments/transactions.csv` is removed/absorbed.
- **Account two-tier classification retained** ✓ — Keep `account_group` (enum) + `account_type`; `status` (draft/active/frozen/closed) is the canonical lifecycle field with `is_active` derived.
- **Delete-on-reference: reassign** ✓ *(Locked Round 7)* — When deleting a referenced object, the delete flow surfaces all referencing rows, presents a reassignment picker per referencing collection, and writes the delete + all reassignments atomically. No silent drops; no blocking cancels. Nullable references may be left unlinked. See `docs/product-requirements.md §12` and `docs/architecture/rulesets-and-taxes.md §1`.

### Locked — 2026-06-24 (Round 7 — domain model and safety)

- **Business is a group type, not a module** ✓ — Business P&L is handled by `AccountEngine` for `group_type = business` account groups. There is no standalone `BusinessEngine` module or `Domain/Business/` subfolder. See `docs/architecture/core-domain.md §2`.
- **Markdown viewer/editor is V2** ✓ — In v1, Markdown files are parsed for front matter metadata only. No visual rendering of note body content in the app UI. See `docs/product-requirements.md §4`.
- **Sync-first write gate** ✓ — Write actions are disabled while the workspace or target file is in a syncing/downloading state. Per-file sync state is exposed by `ICloudContainerService`; `WritePlanBuilder` checks it before constructing any write plan. `NSFileCoordinator` serializes all file reads/writes. See `docs/architecture/core-domain.md §3` (ICloudContainerService).
- **Performance baseline: Apple Silicon (M1+)** ✓ — Acceptance criteria are defined against M1-class hardware. Longer times on older Intel machines are acceptable.
- **Tax module scope** ✓ — The tax module estimates payment obligations and organizes documents. It is not a tax computation engine. All tax figures are estimates. See `docs/product-requirements.md §8`.

### Locked — 2026-06-26 (Round 8 — foundation hardening)

- **Ubiquity container identifier format** ✓ — `iCloud.<bundle-id>` reverse-DNS form
  (corrects the bare `OpenFinance` value). One container across dev and distribution.
- **DEBUG default provider** ✓ — Local-folder provider rooted at `~/Finance-Dev/`;
  live iCloud only in Release/TestFlight builds.
- **Manifest location** ✓ — Device-local regenerable cache at
  `~/Library/Application Support/OpenFinance/<workspace_id>/manifest.json`, kept out of
  the synced container. Fields: `path, domain, subtype, schema_version, hash,
  modified_at, byte_size, row_count, last_indexed_at, validation_status`; top level
  `manifest_schema_version, app_version, workspace_id, last_indexed_at`. Sync state and
  repair history are excluded (held in memory / `logs/repair-log.csv`).
- **schema_version storage format** ✓ — Leading `# schema_version: N` comment row;
  tolerant parser; absent → current version + flag for repair.
- **File watching** ✓ — `NSMetadataQuery` (iCloud provider) + FSEvents (local-folder
  provider). `DispatchSource` and hand-rolled `NSFilePresenter`-as-watcher rejected.
  `NSFileCoordinator`/`NSFilePresenter` are for read/write coordination only.
- **7 sync-state UI treatments + conflict UX** ✓ — Treatment table in §5; conflicts
  resolved manually via `NSFileVersion.unresolvedConflictVersions` (no auto-merge).
- **`Account` model shape** ✓ — Single struct with optional nested
  `InvestmentMetadata?`; no `InvestmentAccount` subtype.

### Open decisions (pre-build)

All Phase 1 architectural decisions were locked as of 2026-06-10 (foundation items
hardened in Round 8). Remaining open decisions are tracked in
`docs/project-management.md` by phase. Key open items that gate upcoming build phases:

- `docs/project-management.md` Phase 2 `[DECIDE]`: full per-file enum enumeration and
  the complete validation rule catalog *(R8 locked the format/structure; enumeration
  remains)*
- `docs/project-management.md` Phase 6 `[DECIDE]`: V1 write scope, backup retention policy, export column inclusion *(delete-on-reference behavior locked Round 7: reassign)*

## 22. Recommended implementation stance

Build v1 as:
- app-owned iCloud workspace first
- strict schema first
- single workspace first
- read-mostly with structured writes
- deterministic repair only
- native SwiftUI interface with Observation-based state

That is the lowest-risk architecture for a macOS app whose source of truth is plain files in iCloud Drive, and it fits a Mac-native, project-folder-oriented workflow well.

## 23. Wireframes

#### App shell
![App Shell wireframe](01-app-shell.svg)
Left sidebar with collapsible navigation sections that open and close independently.
> **Outdated (Round 5):** Overview is now the default landing screen reached via the sidebar header ("Finance Dashboard"), not a nav item; the issues chip moves to the global header (left of sync status); the local-actions row moves onto the page-title line (right-aligned); no contextual filter bar. Needs a new wireframe.

#### Accounts
![Accounts wireframe] *(not yet produced)*
> **New (Round 5):** Account-group screen with an individual-account card section above an inline transaction ledger (no sub-tabs); a dedicated per-account screen with a transactions table; "Account groups" / "Personal Accounts" labels. Needs a new wireframe.

#### Overview dashboard
![Overview wireframe](02-overview.svg)
> **Outdated (Round 1):** Monthly Snapshots and Annual Snapshots views removed. Issues table is now surfaced inline here. Needs a new wireframe.

#### Personal budget overview
![Personal Budget wireframe](03-personal-budget.svg)
> **Outdated (Round 1):** Rules section removed. Pie chart overview added. 3-month trailing averages added. Needs a new wireframe.

#### Savings Goals
![Savings Goals wireframe](04-savings-goals.svg)
> **Outdated (Rounds 1, 4):** Savings Goals is now part of the unified Savings & Investments module. Active/archived states removed — goals are a flat list. Needs to be replaced by a combined wireframe.

#### Investments
![Investments wireframe](05-investments.svg)
> **Outdated (Rounds 1, 4):** Investments is now part of the unified Savings & Investments module. Holdings table is now the primary surface; the benchmark heat map is a holdings table view toggle; the sleeve table moves to the bottom of the Portfolio overview. Needs to be replaced by a combined wireframe.

#### Business
![Business wireframe](06-business.svg)

#### Taxes
![Taxes wireframe](07-taxes.svg)
> **Outdated (Rounds 1, 4):** Deductions view, per-account tax summary, and tax archive not represented. Estimated payments and gains & income are now merged into Current Tax Year; the prep checklist is its own full-width screen. Needs a new wireframe.

#### Notes
![Notes wireframe](08-notes.svg)
> **Deferred to V2.**

#### Issues
![Issues wireframe](09-issues.svg)
> **Deferred to V2** as a standalone view. Issues are surfaced in the Overview table in v1.

---

#### Wireframes needed (not yet produced)

- `accounts-overview.svg` — Accounts card grid and per-account detail view
- `budget-updated.svg` — Budget pie chart overview with trailing averages
- `overview-updated.svg` — Revised Overview with Issues table inline
- `portfolio-overview.svg` — Holdings-focal Portfolio with standard ⇄ heat-map toggle and sleeve table at bottom (replaces `savings-investments.svg`)
- `taxes-current-year.svg` — Consolidated Current Tax Year with payments, gains/income, and deductions inline (replaces `taxes-updated.svg`)
- `taxes-prep-checklist.svg` — Full-width prep checklist with educational content

## 24. Changelog

### Round 8 — 2026-06-26
Source: `docs/_refinement/r8-review.md` (foundation-hardening pass over Phase 1–2 open items; dispositions confirmed by principal)

- **§5 — Container identifier corrected** to the `iCloud.<bundle-id>` reverse-DNS form; bare `OpenFinance` resolves to `nil`. One container across dev/distribution.
- **§5 — DEBUG local-folder provider** (`~/Finance-Dev/`) is the default in debug builds; live iCloud only in Release/TestFlight.
- **§5 — 7 sync-state UI treatment table** added; per-file state sourced from `NSMetadataQuery`. New **Conflict resolution (v1)** subsection: manual via `NSFileVersion`, no auto-merge.
- **§9 — Manifest moved** to a device-local cache in Application Support (out of the synced container); field set defined; sync state + repair history excluded.
- **§9 — schema_version format** locked: leading `# schema_version: N` comment row, tolerant parser.
- **§21 — New Round 8 lock block** (container ID, DEBUG provider, manifest, schema_version, file-watching via `NSMetadataQuery`+FSEvents, sync-state/conflict UX, single `Account` struct). Open-decisions list updated.
- Cascades to `docs/architecture/*` (core-domain services incl. `[FIX-S6]`, FileWatcher, Account shape, goal `status` enum; containers schema convention + `[FIX-S4/S7/S9]`; data-pipelines sign-flip; rulesets validation catalog), `docs/product-roadmap.md` (new Phase 0 track), `docs/product-requirements.md` (data-model cleanup), and `docs/project-management.md` (retirements).
- **Spec-review follow-up (2026-06-26):** §9 `domain` enum corrected — added `accounts` + `meta`, removed `business` (a `group_type`, not a domain folder); `AccountGroup` added as an explicit canonical entity in `docs/architecture/core-domain.md §1` (and the Phase 1 Core Data Models list). Surfaced during the `specs/002-foundation-architecture` review.

### Round 7 — 2026-06-24
Source: `docs/_refinement/r7-review.md` (Round 7 synthesis — MVP prep + direction decisions B1–C5)

**Section A — doc-sync debt (applied first pass):**
- **Architecture split (A3):** Extracted §6–8 and §10–16 to `docs/architecture/` (`core-domain.md`, `containers-and-budgets.md`, `rulesets-and-taxes.md`, `data-pipelines.md`). This file now serves as the overview and locked-decisions record; detailed specs live in the architecture directory. Section stubs with direct links replace the moved sections.
- **Pipeline diagrams (A4):** Added ingestion pipeline diagrams to `docs/architecture/data-pipelines.md §3` (CSV import pipeline, balance derivation, multi-entry group write, file-watch re-index).
- **Manifest path corrected (FIX-C5):** Updated the §9 manifest example path from `"Personal/transactions/2026-05.csv"` to `"Accounts/transactions/2026-05.csv"` / `"domain": "accounts"`.
- **`migrate-r6.swift` script** added to `docs/architecture/data-pipelines.md §2` optional scripts.
- **Advanced workspace mode** clarified in §5 as V2 only (FIX-S8).
- **`OverviewEngine` stub contract** documented in `docs/architecture/core-domain.md §3`.
- **`AccountEngine` read-only constraint** stated explicitly in `docs/architecture/core-domain.md §3`.

**Section B/C — direction decisions (applied second pass):**
- **§21 B1 — Delete-on-reference locked: reassign.** Write preview surfaces referencing rows + reassignment picker; delete + reassignments written atomically. Updated `docs/architecture/rulesets-and-taxes.md §1`, `docs/product-requirements.md §12`.
- **§21 B3 — Business module resolved: group type under Accounts.** No `BusinessEngine` or `Domain/Business/` subfolder. `AccountEngine` owns all business P&L for `group_type = business`. `[FIX-C3]` and `[FIX-S2]` retired. Updated `docs/architecture/core-domain.md §2–3`.
- **§21 B4 — Markdown viewer/editor: V2.** In v1, only front matter is parsed. Updated `docs/product-requirements.md §4`.
- **§21 C1 — Sync-first write gate locked.** Write actions disabled while workspace/file is syncing; `ICloudContainerService` exposes per-file sync state; `WritePlanBuilder` gates on it; `NSFileCoordinator` serializes all file I/O. Approach documented in `docs/architecture/core-domain.md §3` (ICloudContainerService). Updated `docs/product-requirements.md` NFR Reliability.
- **§21 C2 — Performance baseline: M1+.** Updated `docs/product-requirements.md` NFR Performance.
- **§21 C5 — Tax scope guardrail.** Module goals: estimate payment obligations + organize documents. Not a computation engine. Updated `docs/product-requirements.md §8` and non-goals.

### Round 6 — 2026-06-23
Source: `docs/_refinement/r6-review.md` (fourth prototype review — data structuring & IA); update plan `docs/_refinement/r6-update-technical-design.md`

- §6/§8: renamed `entities.csv`→`account-groups.csv` (`entity_id`→`account_group_id`, `entity_type`→`group_type`), `holdings.csv`→`assets.csv` (`holding_id`→`asset_id`, `market_value`→`current_value`, `asset_class` redefined + new `security_class`), `deductions.csv`→`tax-adjustments.csv` (`deduction_id`→`tax_adjustment_id`, `deduction_type`→`adjustment_type` union enum)
- §6/§8: added `Accounts/liabilities.csv` (Liability), `Investments/portfolios.csv` (Portfolio), `Taxes/estimates.csv` (Tax-estimate), `Taxes/documents.csv` (Tax-document)
- §8.2: transactions gained `type`, `group_id` (generalized from `transfer_group`), `group_role`, `sending_asset_id`/`receiving_asset_id`/`liability_id`, `source_id`, `tags`, and optional trade columns; investment trades fold in as `type = trade` rows
- §8.4: budgets split into a Budget definition (scope) + Budget-allocation lines
- §8.9: `Investments/transactions.csv` reserved/absorbed into the unified ledger
- §8.12: sleeves re-parented under portfolios (`portfolio_id`), +`goal`/+`target_allocation_percentage`
- §8.21: accounts `entity_id`→`account_group_id`, +`status` lifecycle (`is_active` derived), +derived `current_balance`/`available_balance`; two-tier `account_group`+`account_type` retained
- §8.3: categories `entity_id`→`account_group_id`, +`parent_category_id`, +`sort_order`, `group_id`→`category_group_id`
- §9/§10/§12/§13/§15: metadata key renamed; data model + engines updated (liability balances, Portfolio container, `TaxAdjustmentEngine`); multi-entry group write + validation rules added
- §21: reopened the deductions-file decision; added the Round 6 lock block (storage-name alignment, first-class Liability, Portfolio container, multi-entry, trades-in-unified-ledger, two-tier account classification)
- Overrides the r5 object-model audit where they differ (`account_group_id` not `group_id`, Portfolio not Strategy, `asset_class` not `asset_kind`, no group nesting) — r6-review takes priority *(delete-on-reference behavior locked in Round 7: reassign)*

### Round 5 — 2026-06-15
Source: `docs/_refinement/r5-review.md` (third prototype review — functional details); update plan `docs/_refinement/r5-update-technical-design.md`

- §4: Overview removed as a nav item — it is the default landing screen reached via the sidebar header ("Finance Dashboard"); removed the Contextual filters block (filter bar → V2); issues count moved to a global header chip left of sync status; local-actions row moved onto the page-title line (right-aligned); account labels "themes/entities" → "account groups", "Personal Assets" → "Personal Accounts", "New entity" → "New group"
- §11: Added Swift Charts as the charting dependency; charts are real charts, not placeholder SVGs
- §13: Delete is now a first-class structured write for all user-addable objects; added the edit/delete UI placement convention (right-panel bottom vs. dedicated-screen edit flow)
- §15: Added a delete-with-reference-check write rule
- §16: Accounts — account-group screens show an individual-accounts card section and (business) ledger inline below the net-income chart; sub-tabs removed; new per-account detail screen; Budget — Spend Mix / Spending Variance panels set to 50/50; per-screen filter bar removed
- §20/§23: Noted dashboard-default + per-account screen + real charts; flagged app-shell and added Accounts wireframes
- No CSV file specs changed; deeper object-model work (entity→group rename, nesting, Budget/Strategy containers, asset kinds) deferred — see `docs/_notes/object-model-audit.md`

### Round 4 — 2026-06-12
Source: `docs/_refinement/r4-review.md` (second prototype review); update plan `docs/_refinement/r4-update-technical-design.md`

- §4: Savings & Investments sidebar reduced to Overview, Goals, Portfolio (Assets removed — holdings live inside the Portfolio view); Taxes sidebar confirmed already trimmed (Round 3)
- §8.5: Removed `status` column from `Savings/goals.csv`; goal active/archived lifecycle deferred to V2 with explanatory note
- §10: Removed stray `InvestmentAccount` from the canonical entity list (Round 3 leftover — the entity was already folded into `Account`)
- §12: `SavingsGoalEngine` noted as having no goal lifecycle states — no status branching in v1
- §16: Restructured Savings & Investments — holdings table is the primary Portfolio surface; benchmark heat map is now a holdings table view toggle; sleeve table appended at the bottom of the Portfolio view; removed the standalone Assets and sleeve-only Portfolio subsections; Goals shows a flat list
- §16: Taxes — Estimated payments, Gains & income, and Deductions confirmed inline within Current tax year with explicit no-separate-screen notes; added "must NOT show the prep checklist" to Current tax year; Prep checklist rewritten as a full-width focal screen with educational content
- §20: Reworded prototype order to fold removed screens into parent steps
- §23: Flagged Savings Goals, Investments, and Taxes wireframes as outdated (Round 4); replaced two planned wireframes and added `taxes-prep-checklist.svg` to the needed list
- No CSV file specs removed — sleeves (§8.12/§8.13), benchmark (§8.11), and estimated payments (§8.19) all retained; only presentation surfaces changed

### Round 3 — 2026-06-10
Source: User direction — sidebar navigation structure refinement; user decision — locked all Phase 1 open architectural decisions before build starts.

- §4 (initial): Clarified sidebar definition: static, expandable groups only where specified; removed "Dashboard" sub-item from Overview (now a leaf item); renamed "All accounts" → "Overview" and "Themes & Entities" → "Themes / entities" under Accounts; removed "Specific account links" and "Specific category links"; replaced Savings & Investments nested Goals/Portfolio structure with flat items (Overview, Goals, Assets, Categories); simplified Taxes to three items (Current tax year, Prep checklist, Tax archive), removing Estimated payments, Gains & income, and Deductions as sidebar navigation items
- §4 (audit resolution): Added data-driven links note explaining the Themes / entities pattern; added "Portfolio" back to Savings & Investments sidebar for sleeve navigation; removed "Workspace root", "Nested saved views", and "Nested report links" from App shell Left sidebar abstract list; removed "Business" from the module-sections filter note (Business is a theme type, not a top-level section); removed undefined "Categories" item from Savings & Investments sidebar (deferred — category and tag systems for Budget and S&I to be considered together)
- §5: Updated workspace resolution path to use confirmed iCloud container identifier `OpenFinance`; updated code example
- §6: Removed `Investments/accounts.csv` from folder tree; updated folder design rule to reflect unified master registry
- §8.7: Removed separate `Investments/accounts.csv` spec; replaced with note redirecting to unified `Accounts/accounts.csv`
- §8.21: Added optional investment-specific columns (`tax_treatment`, `performance_tracking`) to master accounts registry; updated bootstrap note to list six seed accounts
- §10: Updated `Account` entity note to remove `InvestmentAccount` as a separate type; investment-specific fields are optional properties on `Account`
- §8.2: Clarified `amount` column note with locked sign convention; updated behavior note with normalization rule for import
- §9: Updated `schema_version` metadata attribute description; added "Schema version migration policy" subsection
- §14: Updated `bootstrap-workspace` purpose to list six seed accounts
- §16: Restructured Savings & Investments requirements under nav item headings (Goals, Assets, Portfolio) — sleeve content explicitly assigned to Portfolio; restructured Taxes requirements under nav item headings (Current tax year, Prep checklist, Tax archive) — Estimated payments, Gains & income, and Deductions explicitly placed within Current tax year
- §21: Locked all six previously-open Phase 1 decisions; added iCloud container identifier and workspace bootstrap seed accounts as additional locked decisions; added Phase 2 locked section with amount sign convention and schema_version migration policy

### Round 2 — 2026-06-09
Source: User direction — future-proofing for multi-cloud and additional file formats.

- §2: Added storage provider abstraction as a primary design goal
- §5: Added "Storage provider abstraction" subsection with `CloudStorageProvider` protocol shape and V2 provider list (Google Drive, Dropbox, local folder)
- §7: Added xlsx UTType note with V2 designation and CSV-boundary conversion strategy
- §11: Added `CloudStorageProvider.swift` (protocol) to Platform module layout; annotated `ICloudContainerService` as v1 conforming implementation
- §12: Added `CloudStorageProvider` protocol service entry; updated `WorkspaceManager` and `ICloudContainerService` descriptions to reflect protocol relationship
- §21: Added `CloudStorageProvider` protocol surface as a new open decision

### Round 1 — 2026-06-08
Source: `docs/product-requirements.md` (post Round 1 updates), `docs/_refinement/r1-update-technical-design.md`

- §3: Added accounts to domain layer list
- §4: Updated primary navigation (Accounts added, Savings Goals + Investments → Savings & Investments, Rules removed, Monthly/Annual Snapshots removed, Notes/Issues/Files marked V2); updated sidebar nested structure; added right panel collapsibility spec; added Overview no-filters policy
- §6: Added `Accounts/` folder with `accounts.csv` and `account-rules.csv`; removed `Personal/rules.csv`; added `Taxes/deductions.csv` and `Taxes/archive/`; added `account.schema.json` and `tax-deductions.schema.json` to `.finance-meta/schemas/`; updated folder design rules
- §8: Added specs 8.21 (accounts registry), 8.22 (account rules), 8.23 (tax deductions), 8.24 (tax archive)
- §9: Added `account_group` to metadata attributes table
- §10: Added Account, AccountRule, AccountEstimate, BenchmarkPeriod, DeductionRecord, TaxArchiveYear to canonical entities; added AccountSummaryCard, TaxDeductionSummary to cross-domain entities; added notes on Account vs InvestmentAccount relationship
- §11: Added `Domain/Accounts/`; added `Domain/Taxes/DeductionEngine.swift`; renamed `UI/Savings/` + `UI/Investments/` → `UI/SavingsInvestments/`; added `UI/Accounts/`; added `UI/Files/` (V2); marked Notes/Issues/Files (V2)
- §12: Added AccountEngine description; expanded TaxEngine into TaxEngine + TaxPrepEngine + DeductionEngine with distinct responsibilities; updated BenchmarkEngine for heat map periods; updated LinkingEngine
- §16: Replaced all section requirements — Overview (KPI cards, no filters, inline issues), Accounts (new section), Budget (pie chart, trailing averages, no Rules), Savings & Investments (merged, benchmark heat map), Taxes (deductions, per-account rates, archive), Notes/Issues marked V2
- §20: Reordered prototype sequence — Accounts moved to step 4 (before Budget); Issues/Notes moved to end as V2 steps 11–12
- §21: Split into Locked and Open sections; locked 8 decisions from PRD; added 5 open questions for build-start decisions
- §23: Flagged outdated wireframes; added list of 5 needed wireframes
