# Feature Specification: Parsing, Validation & Infrastructure (Phase 2)

**Feature Branch**: `003-parsing-validation`  
**Created**: 2026-06-28  
**Status**: Draft  
**Input**: User description: "Phase 2 — Parsing, Validation & Infrastructure. Build the full Parsing layer and Validation engine so raw CSV/Markdown files on disk become typed domain records. Cover the CSV parser, schema registry, normalizer, Markdown front-matter parser, the three-tier validation rule catalog and engine, safe auto-repair with preview/backup/log, typed workspace settings, the validate/repair developer CLIs, and the one-time R6 schema migration. Milestone: every supported file type parses into typed domain records, the validation engine detects and classifies all defined issue types, and auto-repairable fixes apply with preview."

> **Context.** This is Phase 2 of the roadmap (`docs/product-roadmap.md` Phase 2). It builds directly on the merged Phase 1 foundation (`specs/002-foundation-architecture` — workspace provisioning, the device-local file index/manifest, sync-state handling, and the canonical domain models). Phase 1 *discovered, classified, and hashed* `.csv`/`.md` files and defined the `ValidationIssue`/`RepairAction` contract as stubs; Phase 2 turns those files into **typed domain records**, makes the validation contract real, and ships deterministic, previewable repair. Nothing here is a finished end-user module — it is the read pipeline every Phase 3/4 domain engine depends on. The seven principles in `.specify/memory/constitution.md` (v1.1.0) govern this work, and the technical mechanisms are fixed by `docs/technical-design.md §21` and `docs/architecture/` (notably `containers-and-budgets.md §3` for file specs, `rulesets-and-taxes.md §1` for validation rules, and `data-pipelines.md` for read/repair flows). This spec states the *outcomes* required.

## Clarifications

> Decisions inherited as locked from `docs/technical-design.md §21`, `docs/architecture/rulesets-and-taxes.md`, and `docs/project-management.md` (Round 8) are recorded in **Assumptions**. Two genuinely-open Phase 2 items — the full per-column enum enumeration and the full per-rule validation catalog — are *scope of this feature*, not blockers, and are addressed in the requirements rather than as clarifications.

### Session 2026-06-28

- Q: When the normalizer hits an unconvertible value in one column of an otherwise-valid row, what happens to the row? → A: Retain a **partial typed record** — the bad field is nulled and flagged, the other fields type normally, and a normalization warning is emitted naming file/row/column. The row is never dropped and the file never aborts.
- Q: Where does `CSVSchemaRegistry` load the authoritative schema definitions from at runtime? → A: The app **bundles the canonical schemas as authoritative resources**; bootstrap copies them into the workspace `.finance-meta/schemas/` for transparency and repair-templating, but the registry always loads from the bundled copy — the workspace copy is never the runtime source.
- Q: Do parse/normalization warnings join the validation issue stream or stay a separate channel? → A: **Unify** — `ValidationEngine` lifts parse/normalization warnings into `ValidationResult` as file-level `ValidationIssue`s, so a single issue stream feeds the Overview badge, repair classification, and reporting. `CSVParseResult` still records them at parse time.
- Q: Does Phase 2 validation run as a full-workspace pass only, or also incrementally per-file? → A: **Full-workspace pass only** in Phase 2 (cross-file rules need whole-workspace context); incremental/cached revalidation wired to `FileWatcher` events is deferred to Phase 7 projection caching.
- Q: How is the one-time R6 migration triggered? → A: **Detect-and-prompt** — when a pre-R6 workspace is detected the app surfaces it and prompts the user to run the previewable migration (consistent with the Phase 1 locked "detect version mismatch → prompt to run script" decision); it never auto-applies, and it is also available as an explicit CLI/action.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Files become typed domain records (Priority: P1)

The workspace is full of plain CSV and Markdown files the user owns. This story turns each managed file into **typed, validated-shape domain records** — dates become real dates, amounts become exact decimals, enums become known cases, and every record carries a back-pointer to the file and row it came from. A registry of canonical schemas (one per managed file type) defines the expected columns, types, required-vs-optional flags, and enum value sets, so parsing is strict and predictable. Markdown notes contribute their front-matter metadata (type, period, linked IDs) even though their bodies are not rendered in v1.

**Why this priority**: Every downstream domain engine (Accounts, Budget, Savings, Investments, Tax, Overview) reads typed records, not raw strings. Without this, no projection can be built. It is the irreducible MVP slice of Phase 2 — the moment files stop being opaque text and become data the app can reason about.

**Independent Test**: Run the parser over a realistic fixture workspace (generated by `fixture-generate`). Verify every managed CSV file type parses into typed records with correct types and attached source provenance, every enum value resolves to a known case, and every Markdown note yields its front-matter fields. A malformed value (bad date, bad decimal, unknown enum) is reported as a typed parse/normalization warning against the exact file and row, not a crash.

**Acceptance Scenarios**:

1. **Given** a valid managed CSV file, **When** it is parsed, **Then** each row becomes a typed record with normalized dates (ISO 8601), exact decimal amounts, resolved enum cases, and `source_file` + `source_row` provenance.
2. **Given** a CSV whose headers differ only by case or surrounding whitespace, **When** it is parsed, **Then** headers map to the canonical columns without error (case-insensitive, trimmed).
3. **Given** a CSV with a value that cannot be normalized (e.g. `"abc"` in an amount column), **When** it is parsed, **Then** a typed normalization warning is produced naming the file, row, and column, and parsing of the remaining rows continues.
4. **Given** a Markdown note with YAML front matter, **When** it is parsed, **Then** the front-matter block is extracted into typed metadata (type, period, linked entity/account/sleeve IDs, tax year) and the body is preserved as text but not rendered.
5. **Given** a Markdown file with missing or malformed front matter, **When** it is parsed, **Then** the file is handled gracefully (typed result with the front-matter absence flagged) rather than aborting the parse pass.

---

### User Story 2 - The workspace is validated and every issue is classified (Priority: P2)

Once files are typed, the app must tell the user (and itself) whether the workspace is internally consistent. This story runs a full three-tier validation pass — **file-level** (missing required file, bad header, bad date/decimal, invalid enum), **cross-file** (unknown account/account-group/category/asset/liability/portfolio/sleeve/goal reference, duplicate transaction ID), and **domain** (budget period without rows, asset without account, multi-entry group that does not net to zero, gross/net group that does not reconcile, tax payment outside the tax year). Every issue it finds is classified by **severity** (error / warning / info) and **repair class** (auto / manual / none), so the rest of the app knows what blocks a projection, what merely surfaces, and what can be fixed automatically.

**Why this priority**: Validation is the trust layer. It gates writes (Phase 6), drives the Overview Issues table (Phase 3), and decides what repair can touch (US3). It depends on typed records (US1) but must exist before any engine relies on the data being clean.

**Independent Test**: Run validation against a known-good fixture (zero errors) and against a fixture seeded with one instance of every defined issue type. Verify each rule fires exactly once with the correct ID, tier, severity, and repair class, and that valid data produces no false positives. Verify the result groups issues by severity.

**Acceptance Scenarios**:

1. **Given** a fully valid workspace, **When** the validation pass runs, **Then** it reports zero errors and zero false-positive warnings.
2. **Given** a transaction referencing an `account_id` not present in `Accounts/accounts.csv`, **When** validation runs, **Then** the issue is reported as a cross-file rule with severity `error` and repair class `manual` (assisted create, never silent auto-add).
3. **Given** a managed CSV missing an optional column, **When** validation runs, **Then** the issue is reported with severity `warning` and repair class `auto`.
4. **Given** a multi-entry transfer group whose rows do not sum to zero (`SUM(amount) WHERE group_id = X ≠ 0`), **When** validation runs, **Then** a domain rule fires identifying the group.
5. **Given** any detected issue, **When** it is reported, **Then** it carries a stable rule ID (`VAL-<TIER>-<NNN>`), tier, severity, repair class, a human-readable message, and the source file/row it concerns.

---

### User Story 3 - Safe, previewable auto-repair (Priority: P3)

For the subset of issues that are deterministically fixable, the app can repair them — but only safely. This story implements the auto-repair set: inject a missing optional column with empty defaults, normalize header casing to canonical form, create a missing seed file from its template, create a missing required folder, and normalize blank optional fields. Every repair is **previewable** before it runs, **backs up** the target file first, applies **atomically**, logs the change to the user-facing repair log, and is **idempotent** (re-running changes nothing). Manual-only issues are never auto-applied.

**Why this priority**: Repair makes the workspace self-healing without risking user data — directly serving the "Repair when safe" principle. It depends on validation (US2) to know what to fix and on the Phase 1 backup primitive. It precedes the Phase 6 UI that wires these repairs to buttons, and it ships as developer CLIs here.

**Independent Test**: Take a valid fixture, introduce each repairable defect, run repair in preview mode (no writes; a diff is produced), then in apply mode. Verify the fix is correct, a timestamped backup exists, the change is recorded in `.finance-meta/logs/repair-log.csv`, re-running repair is a no-op, and a manual-only issue is never modified.

**Acceptance Scenarios**:

1. **Given** a managed CSV missing an optional column, **When** auto-repair runs, **Then** the column is injected with empty defaults, a backup is created first, and the repair is logged.
2. **Given** a workspace missing a required folder or seed file, **When** auto-repair runs, **Then** the folder/seed file is created from the canonical template without touching unrelated files.
3. **Given** any repair, **When** it is requested in preview mode, **Then** a before/after diff of the affected rows is produced and **no** file is modified until the user confirms apply.
4. **Given** a repair has already been applied, **When** repair runs again, **Then** nothing changes (idempotent) and no spurious backup is created.
5. **Given** a manual-only issue (e.g. conflicting IDs, divergent duplicate transactions), **When** auto-repair runs, **Then** the issue is left untouched and flagged for manual resolution.

---

### User Story 4 - Typed workspace settings (Priority: P4)

The workspace's own configuration — filing status, current tax year, default currency, timezone — lives in `Taxes/settings.csv`, a plain file like everything else. This story reads it into a typed, observable `WorkspaceSettings` value the rest of the app consumes, seeds sensible defaults when the file is absent, and writes changes back through the same safe-write path as any other file.

**Why this priority**: Several Phase 4 tax computations and the bootstrap's standard-adjustment seeding depend on filing status and tax year being typed and available. It is small, self-contained, and enabling, hence the lowest of the core stories.

**Independent Test**: Read settings from a fixture `Taxes/settings.csv` and verify the typed values surface. Delete the file and verify defaults are produced (and optionally seeded). Change a setting and verify it round-trips through a backed-up, atomic write and re-reads identically.

**Acceptance Scenarios**:

1. **Given** a `Taxes/settings.csv` with filing status, tax year, currency, and timezone, **When** settings are read, **Then** a typed `WorkspaceSettings` value exposes each field with its correct type.
2. **Given** no settings file, **When** settings are requested, **Then** typed defaults are produced (not a crash or empty values) and may be seeded to disk.
3. **Given** a settings change, **When** it is written, **Then** the write is backed up and atomic, and a subsequent read returns the new value.

---

### User Story 5 - One-time migration of pre-R6 workspaces (Priority: P5)

A workspace created before the Round 6 object-model rename uses legacy file/column names and a separate investment ledger. This story provides a one-time, deterministic, **preview-able** migration that renames the three legacy files and their FK columns (`entities.csv`→`account-groups.csv` / `entity_id`→`account_group_id`; `holdings.csv`→`assets.csv` / `holding_id`→`asset_id`; `deductions.csv`→`tax-adjustments.csv` / `deduction_id`→`tax_adjustment_id`), folds `Investments/transactions.csv` rows into the unified monthly ledger as `type = trade` rows, seeds the new R6 files, bumps `schema_version`, and updates the manifest — all backed up and reversible by the user declining the preview.

**Why this priority**: Only legacy (prototype-era) workspaces need it; freshly bootstrapped workspaces already use R6 names. It is the lowest priority and may be a no-op for users who never had a pre-R6 workspace, but it must exist so early adopters are not stranded.

**Independent Test**: Generate a synthetic pre-R6 fixture (legacy names + a separate `Investments/transactions.csv`), run the migration in preview (a full change plan is shown, nothing written), then apply. Verify files/columns are renamed, investment rows are folded into the correct monthly ledger files as `trade` rows, new files are seeded, `schema_version` is bumped, the manifest reflects the new state, and no source data is lost.

**Acceptance Scenarios**:

1. **Given** a pre-R6 workspace, **When** migration runs in preview mode, **Then** a complete, human-readable change plan is produced and no file is modified.
2. **Given** the user confirms, **When** migration applies, **Then** the three files/columns are renamed atomically, investment-transaction rows become `type = trade` rows in the unified ledger, new R6 files are seeded, `schema_version` is bumped, and the manifest is updated — each step backed up.
3. **Given** an already-migrated (R6-native) workspace, **When** migration runs, **Then** it detects nothing to do and makes no changes.

---

### Edge Cases

- **Schema-version mismatch on a file**: a file whose `# schema_version: N` marker is older than the registry's current version is detected and routed to the migration/repair path; it is never silently parsed against the wrong schema.
- **Missing `# schema_version` marker**: treated as the current registry version with a flag for repair (per the locked tolerant-parser decision), not rejected.
- **Embedded commas / quotes / newlines in CSV fields**: parsed correctly per RFC-4180 quoting; a quoted field containing a delimiter is one value, not a column split.
- **Leading `#` comment rows** (including the schema-version row): tolerated and stripped by the parser, not treated as data or as headers.
- **Unknown/extra columns** beyond the schema: surfaced as a warning, not a fatal error; known columns still parse.
- **Empty managed file** (header only, zero data rows): parses to zero records cleanly; not an error by itself.
- **Ambiguous sign/normalization on import** is out of scope here — sign-flip is an explicit per-import declaration handled in the Phase 6 import flow, never inferred silently during parsing.
- **Validation false positives on sparse data**: a domain with no data (e.g. no budgets yet) does not raise spurious "missing rows" errors when the absence is legitimately empty.
- **Repair racing a sync**: repair, like any write, is gated on the Phase 1 sync state — a file mid-sync is not repaired until it is fully available.
- **Repair-log file itself**: lives under `.finance-meta/logs/` and is excluded from the file index (per Phase 1 FR-007), so writing it does not trigger a re-index loop.
- **Partial/interrupted migration**: re-running is safe — already-migrated artifacts are detected and skipped (idempotent).

## Requirements *(mandatory)*

### Functional Requirements

**CSV parsing & schema registry**

- **FR-001**: The system MUST parse raw CSV into row records, mapping headers to canonical columns case-insensitively and trimming surrounding whitespace, and MUST tolerate and strip leading `#` comment rows (including the `# schema_version: N` marker).
- **FR-002**: The system MUST provide a schema registry holding one canonical schema per managed file type, each defining column name, type, required-vs-optional flag, and the permitted enum value set for enum columns. The authoritative schema definitions MUST be **bundled with the app** (loaded by the registry at runtime); bootstrap MUST copy them into the workspace `.finance-meta/schemas/` as a transparency/repair mirror, but the workspace copy is never the runtime source. Bootstrap, parsing, and validation all derive from the same bundled definitions so they stay in agreement.
- **FR-002a**: The schema registry MUST cover the full set of managed file types under R6 names (`account-groups.csv`, `accounts.csv`, `liabilities.csv`, `account-rules.csv`, transactions, budget files, savings files, `assets.csv`, prices, dividends, tax-lots, `portfolios.csv`, sleeves, sleeve-targets, benchmarks, `tax-adjustments.csv`, estimates, documents, estimated-payments, settings, and note types). Phase 1 seeded only `account` and `transaction` starter schemas; authoring the remainder is in scope here.
- **FR-003**: Parsing MUST be strict against the registered schema: each typed record MUST carry `source_file` and `source_row` provenance, and the result MUST separate successfully typed records from per-row warnings.
- **FR-004**: The normalizer MUST convert raw strings to Swift types — ISO 8601 dates, exact `Decimal` amounts, booleans, and enum cases — and MUST produce a typed normalization error (naming file, row, column) for any value it cannot convert, without aborting the rest of the parse.
- **FR-004a**: An unconvertible value MUST yield a **partial record**, not a dropped row or a failed file: the offending field is set to null and flagged invalid, every other field in the row types normally, and a normalization warning is emitted. Downstream engines MUST be able to consume a record with one or more flagged fields (e.g. a transaction with a bad date still appears, flagged, rather than silently vanishing from a balance).
- **FR-005**: The system MUST resolve a file's schema by its `schema_version` marker and MUST route a file whose version is older than the registry to the migration/repair path rather than parsing it against a mismatched schema. A missing marker MUST default to the current registry version with a repair flag.

**Markdown parsing**

- **FR-006**: The system MUST extract the YAML front-matter block delimited by `---` from a Markdown file into typed metadata, and MUST handle missing or malformed front matter gracefully (flagged, not fatal).
- **FR-007**: The system MUST classify a note's type from its `type` field and folder path and produce a typed note record carrying its linked entity/account/sleeve IDs, period, and tax year. The Markdown **body** is preserved as text but NOT rendered in v1 (viewer/editor is V2).

**Validation engine & rule catalog**

- **FR-008**: The system MUST provide a rule catalog in which every rule is a value type with a stable ID (`VAL-<TIER>-<NNN>`), tier (file / cross-file / domain), severity (error / warning / info), repair class (auto / manual / none), a message template, and a pure predicate over the parsed workspace.
- **FR-008a**: The catalog MUST enumerate one rule per defined condition across all three tiers as listed in `docs/architecture/rulesets-and-taxes.md §1` (file-level, cross-file, and domain conditions, including the multi-entry balanced-group and gross/net reconciliation rules).
- **FR-009**: The validation engine MUST run a full pass over a parsed workspace — file-level, then cross-file reference checks, then domain logic — and produce a result that groups issues by severity and marks each with its repair class.
- **FR-009b**: Phase 2 scope is a **full-workspace validation pass** (the natural unit for cross-file rules, which need the whole-workspace registry). Incremental/cached revalidation wired to `FileWatcherService` change events is explicitly deferred to Phase 7 (projection caching / invalidate-affected-domains).
- **FR-009a**: The validation engine MUST lift parse/normalization warnings (from `CSVParseResult`, e.g. invalid date/decimal/enum and partial-record flags) into `ValidationResult` as file-level `ValidationIssue`s, so there is a **single issue stream** consumed by reporting, the Phase 3 Overview Issues table, and repair classification. `CSVParseResult` still carries these warnings at parse time; the engine echoes rather than duplicates them.
- **FR-010**: Issue classification MUST follow the locked defaults: missing optional column → warning/auto; unknown `category_id` → warning/manual; unknown `account_id` on a transaction → error/manual; missing required folder → info/auto. Errors block projections/writes; warnings surface without blocking; info is silent/diagnostic.
- **FR-011**: Validation MUST NOT produce false positives on legitimately sparse or empty data (an empty-but-valid domain raises no "missing rows" error).

**Repair**

- **FR-012**: The system MUST implement the auto-repairable fix set: inject a missing optional column with empty defaults, normalize header casing to canonical form, create a missing seed file from its template, create a missing required folder, and normalize blank optional fields.
- **FR-013**: Every repair MUST be offered in a preview mode that produces a before/after diff of affected rows and writes nothing until the user confirms.
- **FR-014**: Before applying any repair, the system MUST create a timestamped backup of the target file (reusing the Phase 1 backup primitive), apply the change atomically, and append a record to the user-facing repair log at `.finance-meta/logs/repair-log.csv`.
- **FR-015**: Repairs MUST be idempotent — re-running an already-applied repair changes nothing and creates no new backup.
- **FR-016**: The system MUST NOT auto-apply any manual-only issue type (conflicting IDs, ambiguous category remap, impossible date repair, divergent duplicate transactions, broken entity linkage); these are flagged for manual resolution only.
- **FR-016a**: Repair writes MUST be gated on sync state — a file mid-sync is not repaired until fully available (consistent with Phase 1 write-safety).

**Settings persistence**

- **FR-017**: The system MUST read `Taxes/settings.csv` into a typed, observable `WorkspaceSettings` value (filing status, tax year, default currency, timezone), produce typed defaults when the file is absent, and write changes back through the backed-up, atomic, sync-gated write path.

**Developer scripts**

- **FR-018**: The project MUST provide a `validate-workspace` developer command that scans a workspace, runs the full validation pass, prints a grouped issue summary, and can optionally write a JSON report.
- **FR-019**: The project MUST provide a `repair-workspace` developer command supporting `--dry-run` (preview/diff only) and `--apply` modes, writing a backup log on apply.

**Migration**

- **FR-020**: The project MUST provide a one-time `migrate-r6` command that, in preview then apply modes, renames the three legacy files/FK columns, folds `Investments/transactions.csv` rows into the unified ledger as `type = trade` rows, seeds the new R6 files, bumps `schema_version`, and updates the manifest — each step backed up — and that is a detected no-op on an R6-native workspace.
- **FR-020a**: Migration MUST be **detect-and-prompt**, never silent: when a pre-R6 workspace (legacy file names or an older `schema_version`) is detected, the app surfaces it and prompts the user to run the previewable migration; it MUST NOT auto-apply. The same migration MUST also be invocable explicitly via the developer CLI / in-app action.

**Continuity with Phase 1**

- **FR-021**: Parsing, validation, repair, and settings MUST consume the Phase 1 contracts (file index/manifest, `CloudStorageProvider`, backup, file coordination, sync state) and the Phase 1 domain models without redefining them; the `ValidationIssue`/`RepairAction` stubs from Phase 1 are made concrete here.
- **FR-022**: Phase 2 code MUST live under the established module layout (`Sources/FinanceWorkspaceKit/Parsing/`, `…/Validation/`, `…/Persistence/`) and the developer commands as SwiftPM executables, consistent with the Phase 1 packaging.

### Key Entities

- **CSVSchema / ColumnDefinition**: The canonical shape of a managed file type — ordered columns with name, type, required/optional, and enum value set; keyed by domain + subtype and `schema_version`.
- **ParsedRecord**: One typed row with normalized field values plus `source_file`/`source_row` provenance, and per-field validity flags so a partially-invalid row is retained with its bad field(s) marked rather than dropped.
- **CSVParseResult**: The outcome of parsing a file — typed records plus per-row parse/normalization warnings.
- **NormalizationError**: A typed failure to convert a raw string to its target type, naming file, row, and column.
- **FrontMatter / NoteRecord**: Extracted YAML metadata and the typed note (type, period, linked IDs, tax year) with an unrendered body.
- **ValidationRule (RuleCatalog entry)**: ID, tier, severity, repair class, message template, and pure predicate.
- **ValidationResult**: Issues grouped by severity, each marked with its repair class and source location; includes parse/normalization warnings lifted from `CSVParseResult` as file-level issues (single unified issue stream).
- **ValidationIssue**: A concrete instance of a fired rule (made real from the Phase 1 stub).
- **RepairAction / RepairPlan**: A previewable, backed-up, atomic fix with a before/after diff; auto-class only.
- **RepairLogEntry**: A user-facing audit row in `.finance-meta/logs/repair-log.csv`.
- **WorkspaceSettings**: Typed, observable workspace configuration (filing status, tax year, currency, timezone).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every managed file type in a realistic fixture workspace parses into typed domain records with correct types and attached source provenance, with zero parser crashes.
- **SC-002**: Every Markdown note type yields its front-matter metadata; a note with malformed front matter is handled without aborting the parse pass.
- **SC-003**: On a known-good fixture the validation engine reports zero errors and zero false-positive warnings; on a fixture seeded with one of each defined issue type, every rule fires exactly once with the correct ID, tier, severity, and repair class.
- **SC-004**: Each repairable defect, when repaired, is fixed correctly, leaves a timestamped backup and a repair-log entry, and re-running the repair is a verified no-op.
- **SC-005**: No manual-only issue is ever modified by auto-repair.
- **SC-006**: `WorkspaceSettings` round-trips: a written change re-reads identically, and a missing settings file yields typed defaults rather than an error.
- **SC-007**: The `validate-workspace` and `repair-workspace` developer commands run end-to-end against a fixture workspace, producing a correct grouped issue summary and a correct dry-run diff respectively.
- **SC-008**: A synthetic pre-R6 fixture is migrated losslessly — files/columns renamed, investment rows folded into the unified ledger as `trade` rows, new files seeded, `schema_version` bumped, manifest updated — and re-running the migration is a no-op.
- **SC-009**: A single malformed value or one unreadable row never aborts a whole-file parse or a whole-workspace validation pass (per-row / per-file resilience, consistent with Phase 1 FR-011a).

## Assumptions

- **Builds on merged Phase 1.** Workspace provisioning, the device-local manifest/index, sync-state detection and write-gating, the backup and file-coordination primitives, and the canonical domain models all exist and are consumed, not rebuilt. The `ValidationIssue`/`RepairAction` Phase 1 stubs are made concrete here.
- **Locked technical decisions are authoritative** (`docs/technical-design.md §21`, Round 8): `schema_version` is a leading `# schema_version: N` comment row (tolerant parser; absent ⇒ current registry version + repair flag); canonical schemas are machine-readable JSON **bundled with the app** (authoritative at runtime) and mirrored into the workspace `.finance-meta/schemas/` at bootstrap; they drive bootstrap + registry + validation; the rule shape is `{ id VAL-<TIER>-<NNN>, tier, severity, repair_class, message_template, predicate }`; classification defaults are as in `rulesets-and-taxes.md §1`; sign-flip on import is an explicit per-import declaration (Phase 6), never inferred during parsing; delete-with-reference defaults to **reassign** (the inbound-reference *lookups* the reassign policy needs are built here on `WorkspaceContext`; both the fired rule, if any, and the reassignment *write flow* are Phase 6 — no static validation issue fires for it in Phase 2).
- **One schema per managed file type.** The exact set is defined by the file specifications in `docs/architecture/containers-and-budgets.md §3`, not pinned to a fixed count in this spec (the historical "28"/"24" wording is reconciled to "one per managed file type").
- **Markdown is metadata-only in v1.** Front matter is parsed and typed; bodies are not rendered (viewer/editor is V2).
- **Note front matter is free-form metadata in v1.** The parser extracts and types whatever keys are present; only the *presence* of a front-matter block is validated (the `missing required front matter` rule). No per-note-type front-matter schema is authored in Phase 2 — note typing is by `type` field + folder path (FR-007).
- **No end-user UI ships in Phase 2.** Validation issue cards, repair preview panels, and the indexing-progress state are Phase 2 **Design `[DECIDE]`** items (see `docs/project-management.md`) and Phase 5 build work — Phase 2 delivers the engine plus developer CLIs, not polished views.
- **Migration audience is prototype-era workspaces only.** Freshly bootstrapped workspaces already use R6 names, so US5 is frequently a no-op; it exists to avoid stranding early adopters.
- **Platform/toolchain** matches Phase 1: macOS 15+, Swift 6, SwiftPM package (`FinanceWorkspaceKit` library + executables), Observation-based state. `swift test` runs in macOS CI.
- **Constitution compliance** (`.specify/memory/constitution.md` v1.1.0): plain files stay canonical (parsing/validation derive a read model, never an authority); repairs are deterministic, previewable, backed up, atomic, and user-confirmed; iCloud conflicts are never silently merged; the read model is always regenerable from files.

## Dependencies

- The merged Phase 1 foundation (`specs/002-foundation-architecture`): provider abstraction, manifest/index, sync state + write gate, backup, file coordination, and the canonical domain models.
- The canonical specs and locked decisions in `docs/technical-design.md §21`, `docs/architecture/` (`containers-and-budgets.md §3` file specs, `rulesets-and-taxes.md §1` validation rules, `data-pipelines.md` read/repair flows), and `.specify/memory/constitution.md`.
- `fixture-generate` (Phase 1) for realistic test workspaces; a synthetic **pre-R6** fixture must be added for US5.

## Open Phase 2 Work Items (tracked in `docs/project-management.md`)

These are in scope for this feature and are resolved by completing it, not by clarification:

- **CSV spec gaps** — enumerate the full enum value sets (`account_group`, `account_type`, `trade_type`, `frequency`, `adjustment_type`, `status`) and the required-vs-optional flag per column, authored as the **bundled** JSON schemas (mirrored into `.finance-meta/schemas/` at bootstrap; partially resolved R8: format locked).
- **Validation rule catalog** — enumerate the full per-rule catalog, one `VAL-…` entry per condition (partially resolved R8: rule shape + classification defaults locked).
- **R6-M1…M5** — schema renames in the registry (M1), `liabilities.csv` (M2), `portfolios.csv`/sleeves (M3), `group_id`/`group_role` transaction columns (M4), and the `migrate-r6` script (M5).
