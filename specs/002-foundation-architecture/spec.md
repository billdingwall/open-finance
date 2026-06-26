# Feature Specification: Foundation & Architecture (Phase 1)

**Feature Branch**: `002-foundation-architecture`  
**Created**: 2026-06-26  
**Status**: Draft  
**Input**: User description: "Phase 1 — Foundation & Architecture. Establish the foundation layer of the FinanceWorkspaceApp (native macOS, iCloud-backed, CSV/Markdown files as source of truth). Platform layer, file indexing, core data models, and workspace bootstrap. Milestone: the app launches, resolves the iCloud workspace, creates the initial folder structure on first run, scans and hashes all files, persists the manifest, correctly detects and exposes the 7 iCloud sync states, and the bootstrap script produces a valid scannable workspace."

> **Context.** This is the foundation phase of the roadmap (`docs/product-roadmap.md` Phase 1, including the R8 "Phase 0" environment sub-track). Nothing is user-visible as a finished module yet — it builds the floor every later phase stands on. The app is an interface *over* plain CSV/Markdown files the user owns in iCloud Drive; it is not a database. All detailed technical decisions are locked in `docs/technical-design.md §21` and `docs/architecture/`, and the seven principles in `.specify/memory/constitution.md` govern this work. This spec states the *outcomes* required; the implementation mechanisms are fixed by those locked decisions.

## Clarifications

### Session 2026-06-26

- Q: When `FileIndexService` can't read or hash an individual file during a scan, what happens? → A: Skip the failing file, record it in the manifest with an `error` status, log it, and continue indexing everything else (resilient per-file isolation).
- Q: Does the file index include the app-managed `.finance-meta/` subtree (whose `logs/` are `.csv`)? → A: No — exclude the entire `.finance-meta/` subtree from indexing; the index covers the finance content tree plus the root `Workspace.md` descriptor.
- Q: Where do foundation-level failures (workspace resolution, indexing, sync) get recorded? → A: The macOS unified log (`os.Logger`), surfaced coarsely (available/error) in the app shell; workspace `.finance-meta/logs/` files stay reserved for user-facing audit (repair/import).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - First-launch workspace provisioning (Priority: P1)

A person installs the app and opens it for the first time. The app locates (or creates) their Finance workspace in iCloud Drive, lays down the standard folder structure, writes seed starter files so the workspace is immediately valid, and records what it created. From this point the person owns a real, file-based workspace — visible in Finder and editable in any spreadsheet/text editor.

**Why this priority**: Without a resolvable, well-formed workspace there is nothing for any later module to read or project. This is the irreducible MVP slice — a workspace that exists, is owned by the user as plain files, and is internally consistent.

**Independent Test**: On a clean machine signed into iCloud, launch the app; verify the `Finance/` folder tree is created, the six seed accounts and seed categories/templates exist (each managed CSV carrying its schema-version marker), and a manifest snapshot is recorded. Re-launching does not duplicate or clobber existing files.

**Acceptance Scenarios**:

1. **Given** a signed-in iCloud account and no existing `Finance/` workspace, **When** the app launches, **Then** the standard folder tree is created, seed files (six starter accounts, default categories, workspace descriptor, manifest) are written, and the workspace validates as complete.
2. **Given** an existing valid `Finance/` workspace, **When** the app launches, **Then** the existing files are preserved untouched and the app resolves to that workspace.
3. **Given** an existing workspace missing a required folder, **When** the app launches, **Then** the missing folder is reported and the app does not silently overwrite unrelated user files.

---

### User Story 2 - Accurate, self-healing file index (Priority: P2)

The app maintains a trustworthy index of every CSV and Markdown file in the workspace — what files exist, how each is classified, their content hash, and when they last changed — so derived views can be built and kept fresh. The index is a disposable cache: if it is lost or corrupted, the app rebuilds it from the canonical files with no data loss. When files change (in-app or edited externally), the index updates incrementally.

**Why this priority**: Every downstream phase derives its read model from this index. It must be correct, incremental, and never the authority over the files themselves.

**Independent Test**: Index a populated workspace; delete the manifest and re-launch → the index is rebuilt identically from scan. Edit one CSV externally → only that file is re-hashed/re-indexed and a change event is emitted; unrelated files use cached results.

**Acceptance Scenarios**:

1. **Given** a populated workspace, **When** the app indexes it, **Then** every `.csv`/`.md` file is discovered, classified by domain/subtype, hashed, and recorded with its modified date and row/byte size.
2. **Given** an indexed workspace, **When** a single file is added, changed, or removed, **Then** the index detects exactly that delta, updates incrementally, and emits a change event without a full rescan.
3. **Given** a missing or corrupt index, **When** the app starts, **Then** the index is regenerated from the files and the result is identical to a fresh scan.

---

### User Story 3 - Sync-state awareness and safe conflict handling (Priority: P3)

Because the workspace lives in iCloud, its files may be downloading, uploading, stale, missing locally, or in conflict at any moment. The app detects each of these conditions per file and for the workspace as a whole, surfaces them, and never writes over a file that is mid-sync. When a genuine conflict occurs, the user is given an explicit, non-destructive choice rather than a silent merge.

**Why this priority**: Data integrity across a user's devices is foundational trust. It must exist before any write flow ships, but the workspace and index (P1/P2) must exist first.

**Independent Test**: Drive the workspace into each of the seven sync states and verify the correct state is detected and reported; force a two-device conflict and verify the app offers Keep mine / Keep iCloud / Keep both and applies the chosen resolution without losing the other version's data.

**Acceptance Scenarios**:

1. **Given** the workspace or a target file is downloading/uploading, **When** the app evaluates write-readiness, **Then** writes to that file are gated until it is fully available.
2. **Given** iCloud reports an unresolved conflict for a file, **When** the user is shown the conflict, **Then** they can choose Keep mine / Keep iCloud / Keep both and no version is silently discarded.
3. **Given** the user is not signed into iCloud or the container is unavailable, **When** the app launches, **Then** the unavailable state is surfaced explicitly (with a local-folder fallback offered) rather than assuming an empty or available workspace.

---

### User Story 4 - Reliable, iCloud-free development environment (Priority: P4)

A developer can build, lint, run, and test the app against a local-folder workspace without touching live iCloud, entitlements, or signing round-trips. A fixture generator produces a realistic dataset, and continuous integration enforces style on every change. The same workspace-resolution code path is exercised in both iCloud and local-folder modes.

**Why this priority**: A solid dev loop accelerates every subsequent phase and de-risks the iCloud-specific code by making it independently testable. It is enabling work, not user-facing, hence lowest priority among the four — but it is the "Phase 0" prerequisite the rest is built on.

**Independent Test**: In a debug build, the app resolves a workspace at the local development folder and runs the full provisioning + indexing path; CI runs the linter to completion on a standard runner; a smoke test resolves a workspace URL successfully in both iCloud and local-folder modes.

**Acceptance Scenarios**:

1. **Given** a debug build, **When** the app starts, **Then** it defaults to the local-folder workspace provider and never requires live iCloud.
2. **Given** the fixture generator is run, **When** it completes, **Then** a realistic multi-month workspace exists that the indexer scans cleanly.
3. **Given** a pull request, **When** CI runs, **Then** linting executes and reports pass/fail; **and** the dual-mode workspace-resolution smoke test passes.

---

### Edge Cases

- **iCloud unavailable mid-session** (sign-out, network loss): the app surfaces the change and gates writes rather than failing silently or corrupting the index.
- **File present only as an undownloaded placeholder**: indexing records it as "missing locally" and offers to download it rather than treating it as empty or absent.
- **Externally renamed/added/removed file** while the app is open: the watcher coalesces rapid changes (debounce) and re-indexes only what changed.
- **Manifest from a different device/app version**: a stale or foreign manifest is treated as a rebuildable cache, never trusted over the files.
- **Partial/incomplete seed from a previous crashed first run**: re-launch completes provisioning idempotently without duplicating existing valid files.
- **Workspace on a non-iCloud local folder** (dev/advanced): resolution and indexing behave identically through the storage-provider abstraction.
- **Double bootstrap**: bootstrap is idempotent and does not overwrite user edits to seed files.
- **Unreadable/unhashable file during scan** (permission error, truncated/locked file, undecodable bytes): the file is recorded with an `error` status and logged; the index pass continues over all other files (FR-011a).

## Requirements *(mandatory)*

### Functional Requirements

**Workspace resolution & provisioning**

- **FR-001**: The system MUST resolve the active workspace location through a storage-provider abstraction supporting an iCloud-backed provider and a local-folder provider, without the rest of the app depending on iCloud directly.
- **FR-002**: On first run with no existing workspace, the system MUST create the complete standard folder tree and write seed files (six starter accounts, default categories, workspace descriptor, and the initial manifest).
- **FR-003**: The system MUST seed every managed CSV with the correct headers and its schema-version marker, generating templates from the canonical schema definitions so the schema registry, validation, and bootstrap stay in agreement.
- **FR-004**: Provisioning MUST be idempotent — re-launching or re-running bootstrap on an existing valid workspace MUST preserve user files and never duplicate or overwrite them.
- **FR-005**: The system MUST validate that the workspace contains the minimum required paths and report any missing required folders/files distinctly from an unavailable workspace.
- **FR-006**: The system MUST remember and restore the last active workspace across launches.

**File indexing**

- **FR-007**: The system MUST recursively discover all `.csv` and `.md` files in the finance content tree (`Accounts/`, `Budget/`, `Savings/`, `Investments/`, `Taxes/`, `Notes/`) plus the root `Workspace.md`, and classify each by domain and subtype using the path → filename → in-file ordering. The app-managed `.finance-meta/` subtree (schemas, backups, logs) MUST be excluded from this index to avoid cataloguing the app's own bookkeeping or triggering a re-index when a log is written.
- **FR-008**: The system MUST compute a content hash for each file and record per-file metadata (path, domain, subtype, schema_version, hash, modified date, byte size, row count, last-indexed time, last validation summary).
- **FR-009**: The system MUST detect additions, deletions, and modifications relative to the prior recorded snapshot and emit change events describing the delta.
- **FR-010**: On file changes, the system MUST re-index incrementally (only affected files) rather than performing a full rescan, coalescing rapid successive changes.
- **FR-011**: The index/manifest MUST be a device-local, regenerable cache stored outside the synced workspace; a missing or corrupt index MUST trigger a rebuild from the files with no data loss.
- **FR-011a**: A file that cannot be read or hashed during a scan MUST be isolated, not fatal: the system records that file in the manifest with an `error` status, logs it (via the unified system log, `os.Logger`), and continues indexing all other files. One unreadable file MUST NOT abort the index pass.

**Sync state & safety**

- **FR-012**: The system MUST detect and expose the seven workspace/file sync states: Available, Not signed into iCloud, Container unavailable, Syncing, Local copy stale, File missing locally, Conflict detected. (These states are specific to the iCloud provider; on the local-folder dev provider only `Available` / workspace-missing apply — the download/upload/stale/conflict/not-signed-in states do not arise.)
- **FR-013**: The system MUST prevent writes to any file (or while the workspace) is in a syncing/downloading state, deferring the write until the file is fully available.
- **FR-014**: On an unresolved iCloud conflict, the system MUST offer a non-destructive manual resolution (Keep mine / Keep iCloud / Keep both) and MUST NOT silently auto-merge or discard a version.
- **FR-015**: All reads and writes on monitored files MUST be coordinated to serialize concurrent access and avoid clobbering files iCloud is concurrently updating.
- **FR-016**: Before any write or repair, the system MUST create a recoverable timestamped backup of the target file.

**Core data model**

- **FR-017**: The system MUST define typed models for the platform entities (Workspace, FileRecord, SyncStatus, ValidationIssue, RepairAction) and all canonical domain entities so downstream phases compile against a stable contract.
- **FR-018**: The Account model MUST be a single type with optional nested investment metadata (no separate investment-account subtype); Liability MUST be a first-class peer entity.
- **FR-019**: The Transaction model MUST support multi-entry groups via a shared group connector and role, so transfers and paycheck splits can be represented as a single atomic unit.
- **FR-020**: The SavingsGoal model MUST carry a lifecycle status limited to `active` and `archived`.

**Development environment**

- **FR-021**: In debug builds, the system MUST default to the local-folder workspace provider so development needs no live iCloud, entitlements, or signing.
- **FR-022**: The project MUST provide a fixture generator that populates a realistic multi-month local workspace for development and testing.
- **FR-023**: Continuous integration MUST run style linting on every change, and a smoke test MUST verify workspace resolution in both iCloud and local-folder modes.

**Application shell (minimal)**

- **FR-024**: The app MUST launch into a minimal macOS window that hosts workspace resolution and surfaces workspace + sync state — including the unavailable / not-signed-in states and the loading/indexing state. This is a foundational launch surface only; the *finished* first-launch onboarding flow, sync-status indicators, and app-shell visual design are deferred to the Phase 1 Design `[DECIDE]` items and not built in this feature.

**Observability & diagnostics**

- **FR-025**: Foundation-level failures (workspace resolution, indexing, sync) MUST be recorded to the macOS unified log (`os.Logger`) and surfaced coarsely (available / error) in the app shell. The workspace `.finance-meta/logs/` files remain reserved for user-facing audit trails (repair, import) and are NOT used for platform diagnostics.

### Key Entities

- **Workspace**: The user-owned `Finance/` file tree (location, identifier, required paths, availability state). The source of truth.
- **FileRecord**: One indexed file — path, domain, subtype, schema_version, hash, modified date, byte size, row count, last-indexed time, validation summary.
- **SyncStatus**: Per-file and workspace-level sync condition (one of the seven states).
- **Manifest**: Device-local, regenerable snapshot of all FileRecords plus top-level workspace metadata (workspace id, app version, manifest schema version, last-indexed time).
- **ValidationIssue / RepairAction**: Stubs of the issue/repair contract consumed in Phase 2.
- **Canonical domain entities**: Account (+ optional InvestmentMetadata), **AccountGroup** (first-class R6 object; `group_type` = personal/employment/business/custom; provides the `account_group_id` referenced by Account and Transaction), Liability, AccountRule, AccountEstimate, Transaction (unified ledger row with multi-entry group/role — Swift type `UnifiedTransaction`), Category, Budget, BudgetAllocation, SavingsGoal (status active|archived), SavingsProgress, Asset, Trade, PricePoint, BenchmarkPeriod, Portfolio, PortfolioSleeve, SleeveTarget, TaxAdjustment, TaxEstimate, TaxDocument, EstimatedPayment, TaxArchiveYear, NoteDocument, plus the cross-domain projection models (AccountSummaryCard, OverviewSummaryCard, MonthlySnapshot, GoalFundingLink, SleeveFundingLink, TaxPrepSummary, TaxDeductionSummary, BusinessMonthlySummary).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On first launch on a clean machine, the app produces a complete, internally consistent workspace (full folder tree, six seed accounts, seed categories, manifest) with zero manual steps.
- **SC-002**: A workspace of a realistic size (12 months of transactions, multiple accounts) is fully scanned, classified, and hashed on cold launch within a few seconds on current Apple Silicon hardware, and the resulting index matches a byte-for-byte re-scan. (Hard performance thresholds are set in Phase 7; Phase 1 targets responsive cold-launch indexing.)
- **SC-003**: A single external file change is reflected in the index without a full rescan, and unrelated files are not re-processed.
- **SC-004**: Deleting the manifest and relaunching reproduces an identical index with no loss of any user data.
- **SC-005**: All seven sync states are each detectable and correctly reported in a controlled test, and no write is ever applied to a file that is mid-sync.
- **SC-006**: A simulated two-device conflict is always resolvable through the manual choice without losing either version's data.
- **SC-007**: A developer can clone the repo and, in a debug build with no iCloud configured, provision + index a fixture workspace end-to-end; CI linting and the dual-mode resolution smoke test pass.
- **SC-008**: Re-running provisioning/bootstrap on an existing workspace never modifies or duplicates user files (idempotent).

## Assumptions

- **No finished end-user module UI ships in Phase 1.** A *minimal* app shell exists so the app can launch and surface workspace + sync state (FR-024); only the *finished* onboarding screens, sync-status indicators, and app-shell visual design are deferred and tracked as Phase 1 Design `[DECIDE]` items, not built as polished views in this feature.
- **Locked technical decisions are authoritative.** The implementation mechanisms (ubiquity container identifier format `iCloud.<bundle-id>`; per-file sync state via the system metadata query; local change-watching via filesystem events; device-local manifest under Application Support; coordinated file access; conflict resolution via the OS file-version API) are fixed by `docs/technical-design.md §21` and `docs/architecture/`. This spec states *what* must hold, not *how*.
- **Platform/toolchain**: macOS 15 (Sequoia) minimum, Xcode 16, Swift 6, Observation-based state. To be bumped to latest stable at build start if newer.
- **Single, app-owned iCloud workspace in v1.** Multi-workspace and additional cloud backends (Google Drive, Dropbox) are V2; the storage-provider abstraction exists so they can be added without restructuring.
- **Canonical schemas exist as data.** The file schemas are authored as machine-readable JSON in the workspace metadata folder (`.finance-meta/schemas/`) and drive bootstrap templates, the schema registry, and validation; full per-file enum enumeration is finalized in Phase 2. (The exact set of schema files is defined by the file specifications, not fixed at a specific count here.)
- **Parsing/validation behavior is Phase 2.** Phase 1 only **discovers, classifies, and hashes** `.csv`/`.md` files and defines the ValidationIssue/RepairAction contract. It does not implement full CSV parsing, Markdown front-matter parsing, or the validation rule catalog (row counts come from line counting, not parsing).
- **Constitution compliance** (aligned to `.specify/memory/constitution.md` v1.1.0): plain files remain canonical (no hidden database); the read model — including the device-local, regenerable manifest cache — is never authoritative over files; `schema_version` is a leading `# schema_version: N` comment row, not a column; transactions live in the unified `Accounts/transactions/YYYY-MM.csv` ledger (no `Personal/`/`Business/` folders); writes are backed up, atomic, previewable, and gated on sync state; iCloud conflicts are resolved by explicit user choice with no silent auto-merge; repairs are deterministic and user-confirmed.

## Dependencies

- A valid Apple developer team and an iCloud container entitlement (`iCloud.<bundle-id>`) for the iCloud provider path; the local-folder provider removes this dependency for development.
- The canonical specs and locked decisions in `docs/technical-design.md`, `docs/architecture/` (core-domain, containers-and-budgets, data-pipelines, rulesets-and-taxes), and `.specify/memory/constitution.md`.

## Known Documentation Inconsistencies (to reconcile before/with planning)

These do not change the requirements above (which follow the locked `§21` decisions), but should be fixed in the canonical docs so `/speckit-plan` reads a consistent source:

1. **Manifest location**: `docs/architecture/containers-and-budgets.md §1` still lists `manifest.json` inside `.finance-meta/`, contradicting the R8 decision (`§9`/`§21`) and the constitution that the manifest is a device-local Application Support cache and `.finance-meta/` holds only `schemas/`, `backups/`, `logs/`.
2. ~~**Constitution drift** (schema_version column, `Personal/`/`Business/` folders, Business-as-module)~~ **Resolved** — `.specify/memory/constitution.md` amended to v1.1.0 (2026-06-26) to match the R6–R8 locked decisions. The Constitution Check gate in `/speckit-plan` now reads a consistent source.
3. **Schema count wording**: the roadmap's "28 file schemas" does not match the ~10 representative `*.schema.json` files in the §1 tree; reconcile the count or state it as "one schema per managed file type."
4. **PRD goal-status** (tracked separately): `docs/product-requirements.md` Scope → Out-of-scope still lists goal active/archived as V2, contradicting the v1 `status ∈ {active, archived}` decision (`[FIX-S7]`) now in the architecture docs and constitution.
