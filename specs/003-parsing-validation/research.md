# Phase 0 Research: Parsing, Validation & Infrastructure (Phase 2)

All foundational mechanisms were locked in `docs/technical-design.md §21`, `docs/architecture/`, and the spec's `/speckit-clarify` Session 2026-06-28. This document consolidates the decisions that govern implementation; there are **no open `NEEDS CLARIFICATION`** items.

---

## 1. CSV parsing strategy

- **Decision**: Hand-rolled RFC-4180-aware parser in `CSVParserService`. Tolerate and strip leading `#` comment rows (including the `# schema_version: N` marker on line 1). Map headers to canonical columns case-insensitively, trimming surrounding whitespace. Emit `[String: String]` row dicts first, then hand to the normalizer.
- **Rationale**: The file shape is fully under our control (we author every managed file via bootstrap/templates), and the only "exotic" requirement is quoted fields containing delimiters/newlines and the leading comment row — both small. A dependency-free parser keeps the SwiftPM package lean and the behavior auditable, matching the Phase 1 "no third-party deps" posture.
- **Alternatives considered**: `TabularData` (Apple) — heavier, geared at analytics DataFrames, awkward for per-row provenance and the leading-comment-row convention. Third-party CSV libs — unnecessary dependency surface for a format we fully own.

## 2. Schema registry source of truth

- **Decision** (clarify Q2): Canonical JSON schemas are **bundled with the app** as `FinanceWorkspaceKit` package resources, loaded at runtime via `Bundle.module`. `CSVSchemaRegistry` always reads the bundled copy. Bootstrap copies the same files into the workspace `.finance-meta/schemas/` as a transparency/repair mirror; that mirror is never the runtime source.
- **Rationale**: Keeps parsing deterministic and immune to a user editing/corrupting the workspace copy (Principle II — the read model is app-regenerable). Still honors Principle I by mirroring the schemas into the workspace as plain, inspectable files. Phase 1 already seeds `workspace-template/.finance-meta/schemas/`, so the mirror path exists.
- **Alternatives considered**: Workspace copy authoritative (rejected — corruptible, breaks determinism); workspace-with-bundled-fallback (rejected — added branching for no v1 benefit since the app owns both copies).
- **Implementation note**: `Package.swift` declares `resources: [.copy("Resources/Schemas")]` (or `.process`) on the `FinanceWorkspaceKit` target. Phase 1 shipped only `account` + `transaction` starter schemas — authoring the rest is Phase 2 work.

## 3. Normalization & partial records

- **Decision** (clarify Q1): `CSVNormalizer` converts raw strings to `Decimal` (amounts), `Date` via ISO 8601 (dates), `Bool`, and enum cases. An unconvertible value yields a **partial record** — the offending field is nulled and flagged invalid, all other fields type normally, and a `NormalizationError` warning is emitted naming file/row/column. Rows are never dropped; files never abort on a bad value.
- **Rationale**: Preserves user data and full traceability (Principle V) — a transaction with a bad date still appears (flagged) rather than silently vanishing from a balance. Aligns with Phase 1's resilient-per-file indexing philosophy (FR-011a).
- **Alternatives considered**: Drop offending row (rejected — silent data loss); strict-abort whole file (rejected — one typo nukes a month of ledger).
- **Amounts**: `Decimal` (not `Double`) for exact money math, per the locked sign convention (negative = debit, positive = credit). Sign-flip on import is an explicit per-import declaration (Phase 6), never inferred here.

## 4. Markdown front-matter parsing

- **Decision**: `FrontMatterParser` extracts the `---`-delimited block at the top of a `.md` file; `MarkdownParserService` produces a typed `NoteRecord` (type, period, linked entity/account/sleeve IDs, tax year) and preserves the body as text **without rendering**. Missing/malformed front matter is flagged, not fatal.
- **Rationale**: v1 is metadata-only (constitution File & Schema Conventions; viewer/editor is V2). A minimal extractor over the delimited block avoids a full YAML dependency, since note front matter is a flat key/value + small lists.
- **Alternatives considered**: Full YAML library (rejected — dependency weight for flat metadata); rendering the body (rejected — explicitly V2).

## 5. Validation rule catalog & engine

- **Decision**: `RuleCatalog` holds rules as value types with the locked shape `{ id: VAL-<TIER>-<NNN>, tier, severity, repair_class, message_template, predicate }`, one entry per condition enumerated in `docs/architecture/rulesets-and-taxes.md §1` (file / cross-file / domain). `ValidationEngine` runs a **full-workspace pass** (clarify Q4) — file-level → cross-file references → domain logic — and produces a `ValidationResult` grouped by severity. Classification follows the locked defaults (missing optional col → warning/auto; unknown `category_id` → warning/manual; unknown `account_id` → error/manual; missing folder → info/auto).
- **Rationale**: Cross-file rules (unknown reference, duplicate ID) need whole-workspace context, so a full pass is the natural unit. Authoring rules as data mirrors the schema approach and keeps the catalog enumerable/testable.
- **Alternatives considered**: Incremental per-file validation now (rejected → deferred to Phase 7 projection caching, clarify Q4); imperative per-rule code scattered across engines (rejected — not enumerable, hard to test one-issue-per-rule).

## 6. Unified issue stream

- **Decision** (clarify Q3): `ValidationEngine` lifts parse/normalization warnings from `CSVParseResult` into `ValidationResult` as file-level `ValidationIssue`s, producing a **single** issue stream for reporting, the Phase 3 Overview Issues table, and repair classification. `CSVParseResult` still records warnings at parse time; the engine echoes (does not duplicate) them.
- **Rationale**: One issue model downstream — Phase 3 doesn't have to merge two parallel channels. The Phase 1 `ValidationIssue` stub becomes the single concrete type.
- **Alternatives considered**: Two separate channels (rejected — pushes a merge burden to every consumer); counting-only hybrid (rejected — Overview would show a count it can't drill into).

## 7. Repair service

- **Decision**: `RepairService` implements only the auto-repairable set (inject missing optional column, normalize header casing, create missing seed file, create missing required folder, normalize blank optional fields). Each repair: produces a before/after diff in **preview** mode (no writes), creates a timestamped backup via the Phase 1 `BackupService`, applies atomically via `FileCoordinatorService`/`AtomicFileWriter`-style temp-and-rename, is **idempotent**, is gated on sync state (Phase 1 `WriteGate`), and appends to `.finance-meta/logs/repair-log.csv`. Manual-only issues are never auto-applied.
- **Rationale**: Directly implements Principle VII and Principle IV. Reuses Phase 1 write primitives rather than reinventing them.
- **Alternatives considered**: In-place mutation without temp file (rejected — not atomic); auto-applying ambiguous fixes (rejected — constitution prohibits speculative repair).

## 8. Settings store

- **Decision**: `SettingsStore` reads `Taxes/settings.csv` into an observable typed `WorkspaceSettings` (filing status, tax year, default currency, timezone); produces typed defaults when absent (optionally seeding); writes back through the backed-up, atomic, sync-gated path.
- **Rationale**: Several Phase 4 tax computations and bootstrap's standard-adjustment seeding need typed filing status / tax year. Small, observation-based, consistent with Phase 1 state patterns.
- **Alternatives considered**: Ad-hoc reads at each call site (rejected — no single typed source, no observability).

## 9. R6 migration

- **Decision** (clarify Q5): `migrate-r6` is **detect-and-prompt** — on detecting a pre-R6 workspace (legacy file names or an older `schema_version`), the app surfaces it and prompts the user to run the previewable migration; it never auto-applies. Also invocable explicitly as a CLI/action. The migration renames the three legacy files/FK columns, folds `Investments/transactions.csv` rows into the unified monthly ledger as `type = trade` rows (assigned to month files by transaction date), seeds the new R6 files, bumps `schema_version`, and updates the manifest — each step backed up. It is a detected no-op on an R6-native workspace.
- **Rationale**: Matches the Phase 1 locked "detect version mismatch → prompt to run script" decision and Principle IV (no silent mutation). Freshly bootstrapped workspaces are already R6-native, so for most users this is a no-op; it exists to avoid stranding prototype-era adopters.
- **Alternatives considered**: Auto-apply on detect (rejected — silent mutation); explicit-only with no detection (rejected — users wouldn't know they need it).

## 10. Testing approach

- **Decision**: Swift Testing, fixture-driven. Extend `fixture-generate` (or add fixtures) for: (a) a fully-valid multi-month workspace (zero-error baseline), (b) a defect-seeded workspace containing one instance of every defined issue type, and (c) a synthetic **pre-R6** workspace for the migration. Tests assert one-issue-per-rule firing with correct ID/tier/severity/repair-class, no false positives on valid/sparse data, repair idempotence + backup + log, settings round-trip, and lossless migration.
- **Rationale**: Maps directly to the spec's Success Criteria (SC-001…SC-009). Runs in macOS CI (`ci-macos.yml`); `swift build` + executables also runnable on a CLT-only machine.
- **Alternatives considered**: Hand-written inline string fixtures only (rejected — doesn't exercise the real bootstrap/template path or realistic volumes).
