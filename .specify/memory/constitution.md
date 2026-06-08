<!--
SYNC IMPACT REPORT
==================
Version: 0.0.0 → 1.0.0
Bump type: MAJOR — initial adoption; all template placeholders populated

Modified principles: N/A (initial version)

Added sections:
  - Core Principles (7 principles derived from docs/PRD.md product principles)
  - File & Schema Conventions
  - V1 Scope Boundaries
  - Governance

Templates reviewed:
  - .specify/templates/plan-template.md  ✅ No changes required
    (Constitution Check gate is generic; /speckit-plan reads this file at runtime)
  - .specify/templates/spec-template.md  ✅ No changes required
  - .specify/templates/tasks-template.md ✅ No changes required
    (Path conventions are illustrative examples replaced by /speckit-tasks)

Deferred placeholders: none
Follow-up TODOs: none
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

- All CSV files MUST include a `schema_version` column or front matter field.
- File classification follows a three-tier hierarchy: (1) folder path → (2) filename →
  (3) in-file metadata or column headers.
- `account_id` references in any transaction file MUST resolve to a record in
  `Accounts/accounts.csv`.
- Monthly personal transaction files MUST follow the `YYYY-MM.csv` naming pattern under
  `Personal/transactions/`.
- Business transaction files MUST follow the `{entity-slug}-YYYY-MM.csv` pattern under
  `Business/transactions/`.
- The `.finance-meta/` directory is app-managed support data only. It is not a source of truth
  for finance content and MUST NOT be hand-edited by users.
- Schema changes MUST increment `schema_version` and MUST be accompanied by a migration note
  in `docs/technical design.md`.

## V1 Scope Boundaries

These boundaries define what is and is not built in v1. All implementation work MUST respect them.
Crossing a deferred boundary requires an explicit constitution amendment.

**In scope for v1:**
- App-owned iCloud ubiquity container (single workspace, single user)
- Modules: Accounts, Budget, Savings & Investments, Business, Taxes
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
3. Propagate changes to `docs/PRD.md`, `docs/technical design.md`, and affected Spec Kit templates.
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
- This constitution MUST be reviewed and potentially amended whenever `docs/PRD.md` or
  `docs/technical design.md` receives a round of prototype-driven updates.

**Reference documents:**
- Product requirements: `docs/PRD.md`
- Technical architecture: `docs/technical design.md`
- Review and update history: `docs/_reviews/`

**Version**: 1.0.0 | **Ratified**: 2026-06-08 | **Last Amended**: 2026-06-08
