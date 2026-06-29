<!--
SYNC IMPACT REPORT
==================
Version: 1.1.0 → 1.1.1
Bump type: PATCH — wording refinement of the migration-script clause to match the SwiftPM packaging
reality and release-scoped migrations (no principle added, removed, or redefined)

Modified principles: none

Modified sections:
  - File & Schema Conventions — migration-script clause: migrations are SwiftPM executable targets
    (run via `swift run <name>`), allowing both per-file (`migrate-{file-type}-v{old}-to-v{new}`)
    and release-scoped multi-file migrations (e.g. `migrate-r6`); replaces the prior mandate of
    `Scripts/migrate-{file-type}-v{old}-to-v{new}.swift`. The "Migrations MUST be recorded in
    docs/technical-design.md" requirement is unchanged.

Rationale: the project is built as a Swift Package (no `Scripts/*.swift` run target), and the R6
rename spans three interdependent files that must migrate atomically as one release migration — both
realities postdate the original clause. Surfaced by /speckit-analyze (finding C1) on the
003-parsing-validation feature. See docs/technical-design.md §9 (already reconciled).

Templates reviewed:
  - .specify/templates/plan-template.md  ✅ No changes required (Constitution Check gate is generic)
  - .specify/templates/spec-template.md  ✅ No changes required
  - .specify/templates/tasks-template.md ✅ No changes required (no migration-naming reference)

Dependent docs:
  - docs/technical-design.md §9 ✅ already updated to the SwiftPM-executable wording (prior step)
  - specs/003-parsing-validation/plan.md ✅ Complexity Tracking row references this PATCH

Deferred placeholders: none

--- Prior amendment (1.0.0 → 1.1.0, MINOR, 2026-06-26) ---
Convention corrections + safety/scope guidance for Rounds 6–8: Principle IV gained the sync-state
write gate + manual conflict resolution; File & Schema Conventions gained the leading-comment-row
schema_version, the unified Accounts/transactions/ ledger, the device-local manifest, and
Markdown-front-matter-only v1; V1 Scope Boundaries set Business as an account-group type and added
Overview + Settings + the tax-estimation guardrail; Governance reference docs expanded.
Follow-up TODO (still open): reconcile the PRD out-of-scope goal-status bullet (active/archived is v1
per [FIX-S7]; PRD still lists it as V2) — a separate PRD edit.
-->

# Open Finance Constitution

## Core Principles

### I. Plain Files First

CSV and Markdown files stored in iCloud Drive are the canonical source of truth. The app MUST NOT
maintain a hidden primary database. All finance data MUST remain readable, editable, and portable
outside the app using standard tools (Finder, Numbers, Excel, a text editor).

- Every writable entity MUST have a corresponding file-based representation.
- The app MUST NOT treat in-memory or cached state as authoritative over file content.
- File paths and schemas MUST be stable and human-interpretable without opening the app.

### II. Read Model Second

The app builds normalized projections from file data. The read model is derived, not primary.
Every derived value MUST be regenerable from source files alone — if the app is deleted and
reinstalled, it MUST produce identical projections from the same files.

- Parsing failures in one file MUST NOT block projections for unrelated domains.
- The app MUST preserve the last known valid projection when a file becomes temporarily unavailable.
- Derived, imported, repaired, and user-edited values MUST be visually distinguished in the UI.

### III. Native Over Generic

macOS conventions, keyboard navigation, and Finder compatibility take precedence over cross-platform
abstractions. The app MUST behave as a first-class macOS citizen.

- Navigation MUST follow macOS `NavigationSplitView` conventions with a stable left sidebar.
- The app MUST support full keyboard navigation across sidebar, main panel, and detail inspector.
- Source files MUST be openable in Finder and the system default editor from within the app.
- The right detail pane MUST be collapsible and closed by default (slide-over, not persistent split).

### IV. Safe Writes Only

Every write to a user file MUST be constrained, validated, previewable, and reversible. Silent or
ambiguous mutations are prohibited.

- The app MUST create a timestamped backup before any write or repair operation.
- Every write flow MUST show the target file, affected rows, and backup behavior before applying.
- Write failures MUST leave the file in its pre-write state (atomic writes required).
- Writes MUST be gated on sync state: the app MUST NOT write to a file that is downloading or
  uploading. Reads and writes on monitored files MUST be coordinated to serialize concurrent access.
- iCloud conflicts MUST be resolved by explicit user choice (keep mine / keep iCloud / keep both).
  The app MUST NOT silently auto-merge files.
- Every repair action MUST be logged to `.finance-meta/logs/repair-log.csv`.

### V. Traceability Always

Every displayed value MUST be traceable to a source file and source row. Aggregated KPIs MUST link
to filtered detail views; detail views MUST link to source records.

- Every KPI and chart point MUST provide a navigation path to the source file and row.
- File paths and modification timestamps MUST be visible in all inspector surfaces.
- The app MUST distinguish clearly between raw imported values and derived values.

### VI. Cross-Domain Visibility

Personal budget, savings, investments, business, and tax workflows are connected through a shared
account registry. The app MUST surface relationships between domains rather than siloing them.

- `Accounts/accounts.csv` is the master account registry. All transaction files MUST reference
  `account_id` from this registry.
- The Overview dashboard MUST draw live data from all domains simultaneously.
- Cross-domain links (budget-to-goal, portfolio-to-tax, business-to-tax) MUST be maintained by
  the `LinkingEngine` and surfaced in the relevant detail views.

### VII. Repair When Safe

The app SHOULD help users create missing files and repair invalid files, but ONLY when the fix is
deterministic, previewable, and low risk.

- Repair actions MUST be classified as auto-repairable or manual-only before being surfaced to the
  user.
- Auto-repair MUST require explicit user confirmation after showing a diff-style preview.
- Speculative or ambiguous repairs are prohibited in v1.
- Repairable issue types: missing optional columns, header casing mismatches, missing seed files,
  missing required folders, blank optional field normalization.

## File & Schema Conventions

These rules govern how workspace files are named, structured, and versioned.

- Every managed CSV MUST declare its `schema_version` as a leading comment row
  (`# schema_version: N`, line 1); Markdown files declare it in front matter. The parser tolerates
  and strips leading comment rows; CSVs do not carry a `schema_version` data column.
- File classification follows a three-tier hierarchy: (1) folder path → (2) filename →
  (3) in-file metadata or column headers.
- `account_id` references in any transaction file MUST resolve to a record in
  `Accounts/accounts.csv`.
- Transactions live in a single unified monthly ledger `Accounts/transactions/YYYY-MM.csv`. Personal
  and business rows share this ledger, distinguished by `account_group_id` and a `BX-` ID prefix;
  multi-entry transactions (transfers, paycheck splits) share a `group_id` connector. There are no
  separate `Personal/` or `Business/` transaction folders.
- In v1, Markdown files are parsed for front-matter metadata only; body rendering is V2.
- The file index/manifest is a device-local, regenerable cache stored in Application Support, outside
  the synced workspace, and is never authoritative over file content; if lost it is rebuilt by a full
  scan. The synced `.finance-meta/` directory holds only `schemas/`, `backups/`, and `logs/`, is
  app-managed support data, and MUST NOT be hand-edited as a source of truth.
- A breaking schema change (renaming, removing, or retyping a column or enum, or adding a required
  column) MUST increment `schema_version` and ship a migration. Migrations are SwiftPM executable
  targets run via `swift run <name>`: a per-file change uses `migrate-{file-type}-v{old}-to-v{new}`;
  a release-scoped change spanning interdependent files (renames that must apply atomically together)
  uses a single release migration, e.g. `migrate-r6`. Adding an optional column is not breaking.
  Migrations MUST be recorded in `docs/technical-design.md`.

## V1 Scope Boundaries

These boundaries define what is and is not built in v1. All implementation work MUST respect them.
Crossing a deferred boundary requires an explicit constitution amendment.

**In scope for v1:**
- App-owned iCloud ubiquity container (single workspace, single user)
- Modules: Overview (default dashboard), Accounts, Budget, Savings & Investments, Taxes — plus
  Settings. Business is an account-group type *within* Accounts (handled by `AccountEngine`), not a
  separate module.
- The Tax module estimates payment obligations and organizes documents; it is not a tax computation
  or filing engine. All tax figures are estimates.
- File validation and issue reporting (surfaced in the Overview dashboard)
- Guided creation of missing required files from templates
- Deterministic repair flows only

**Explicitly deferred (V2 or later):**
- Notes viewer and editor
- Issues management standalone view
- Files explorer
- Budget rules and recurring-rule automation
- Bank account or brokerage sync
- Multi-workspace or multi-user support
- AI-driven analysis or recommendations

## Governance

This constitution supersedes all other guidance documents when implementation decisions conflict.
It is the authoritative reference for project principles and prohibited patterns.

**Amendment procedure:**
1. Identify the principle or section requiring change.
2. Update this file with a version bump per the versioning policy below.
3. Propagate changes to `docs/product-requirements.md`, `docs/technical-design.md`, and affected Spec Kit templates.
4. Update the Sync Impact Report (HTML comment at top of this file).
5. Commit all affected files together in a single commit.

**Versioning policy:**
- MAJOR: backward-incompatible principle removal or redefinition.
- MINOR: new principle or section added, or material expansion of existing guidance.
- PATCH: clarifications, wording improvements, or non-semantic refinements.

**Compliance expectations:**
- Every feature plan MUST include a Constitution Check gate before Phase 0 research and again
  after Phase 1 design.
- Violations (extra abstraction layers, deferred-scope features, unsafe write patterns) MUST be
  documented in the plan's Complexity Tracking table with explicit justification.
- This constitution MUST be reviewed and potentially amended whenever `docs/product-requirements.md` or
  `docs/technical-design.md` receives a round of prototype-driven updates.

**Reference documents:**
- Product requirements: `docs/product-requirements.md`
- Technical architecture: `docs/technical-design.md` (overview + locked decisions §21)
- Detailed architecture specs: `docs/architecture/` (core-domain, containers-and-budgets, rulesets-and-taxes, data-pipelines)
- Implementation roadmap: `docs/product-roadmap.md`
- Agent/build context: `CLAUDE.md`
- Review and update history: `docs/_refinement/`

**Version**: 1.1.1 | **Ratified**: 2026-06-08 | **Last Amended**: 2026-06-29
