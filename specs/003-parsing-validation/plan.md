# Implementation Plan: Parsing, Validation & Infrastructure (Phase 2)

**Branch**: `003-parsing-validation` | **Date**: 2026-06-29 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/003-parsing-validation/spec.md`

> Incorporates the `/speckit-clarify` Session 2026-06-28 answers: partial-record bad-field handling, bundled-authoritative schemas, a unified `ValidationIssue` stream, full-pass validation scope, and detect-and-prompt R6 migration.

## Summary

Build the Parsing layer and Validation engine on top of the merged Phase 1 foundation, so the plain CSV/Markdown files the file index already discovers become **typed domain records** the Phase 3/4 engines can consume. Concretely: a strict, schema-driven CSV parser with a registry covering every managed file type; a normalizer that produces exact typed values and **partial records** on bad fields (never dropping rows or aborting files); a Markdown front-matter parser (metadata-only, no body rendering in v1); a three-tier `RuleCatalog` + `ValidationEngine` that runs a full-workspace pass and emits a **single unified issue stream** (parse warnings lifted into `ValidationResult`); a deterministic, previewable, backed-up, idempotent `RepairService` for the auto-repairable set; a typed `WorkspaceSettings` store; the `validate-workspace` / `repair-workspace` developer CLIs; and a detect-and-prompt one-time `migrate-r6` migration for prototype-era workspaces. No finished end-user UI ships — this is the read pipeline plus developer CLIs.

Technical approach: continue the Phase 1 SwiftPM package (Swift 6, Observation). Files stay canonical; the parsed read model is derived and never authoritative. Canonical JSON schemas are **bundled with the app** as `FinanceWorkspaceKit` resources (authoritative at runtime via `Bundle.module`) and mirrored into the workspace `.finance-meta/schemas/` at bootstrap for transparency/repair. Parsing is RFC-4180-aware, tolerant of leading `#` comment rows (including `# schema_version: N`), case-insensitive on headers, and resilient per-row. Validation rules are authored as data alongside the schemas using the locked `VAL-<TIER>-<NNN>` shape. Repair reuses the Phase 1 `BackupService`, `FileCoordinatorService`, and `WriteGate`, logging to `.finance-meta/logs/repair-log.csv`. The `ValidationIssue`/`RepairAction` Phase 1 stubs are made concrete here.

## Technical Context

**Language/Version**: Swift 6
**Primary Dependencies**: Foundation (`FileManager`, `Decimal`, `ISO8601DateFormatter`/`Date`, `NSFileCoordinator`); a YAML front-matter parser (lightweight hand-rolled extractor over the `---`-delimited block, consistent with the metadata-only v1 scope — no third-party YAML dependency); `Bundle.module` for bundled schema resources; the existing Phase 1 `FinanceWorkspaceKit` services (`FileIndexService`, `ManifestStore`, `BackupService`, `FileCoordinatorService`, `WriteGate`, `CloudStorageProvider`)
**Storage**: Plain CSV + Markdown files (canonical, unchanged). Bundled JSON schemas as package resources; workspace `.finance-meta/schemas/` mirror; user-facing repair log at `.finance-meta/logs/repair-log.csv`. No database.
**Testing**: Swift Testing (`import Testing`); fixture-driven tests against a local-folder workspace produced by `fixture-generate` (valid fixtures + a defect-seeded fixture + a synthetic pre-R6 fixture); runs in macOS CI (`ci-macos.yml`); SwiftLint on the Linux runner
**Target Platform**: macOS 15 (Sequoia) or newer
**Project Type**: Native macOS app delivered as a Swift Package — `FinanceWorkspaceKit` library + `FinanceWorkspaceApp` and developer CLI executables (no `.xcodeproj` yet)
**Performance Goals**: parse + full-workspace validate a realistic 12-month workspace within a couple of seconds on Apple Silicon (M1+). Hard thresholds are set in Phase 7; incremental/cached revalidation is also Phase 7.
**Constraints**: offline-capable; files canonical (no hidden DB); read model regenerable; **resilient per-row / per-file** (one bad value never aborts a file, one bad file never aborts a pass); repairs backed up, atomic, sync-gated, previewable, idempotent, user-confirmed; no silent auto-merge; Markdown body unrendered (v1)
**Observability**: parse/validation outcomes surface as the unified issue stream; foundation-level failures continue to use `os.Logger` (Phase 1); repair actions logged to the user-facing `.finance-meta/logs/repair-log.csv`
**Scale/Scope**: single user, single workspace; one schema per managed file type (~22 CSV types + benchmark series + Markdown note types); the full three-tier rule catalog (one `VAL-…` entry per condition in `rulesets-and-taxes.md §1`)

No open `NEEDS CLARIFICATION` — Phase 2 mechanisms are locked in `docs/technical-design.md §21`, `docs/architecture/` (`containers-and-budgets.md §3`, `rulesets-and-taxes.md §1`, `data-pipelines.md`), and the spec's `/speckit-clarify` Session 2026-06-28.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* — Source: `.specify/memory/constitution.md` v1.1.0.

| Principle / Section | Gate | Status |
|---|---|---|
| I. Plain Files First | No hidden primary DB; CSV/MD canonical; parsed records are derived | ✅ PASS — parser/validator build a derived read model only; bundled schemas are app config, not a data store |
| II. Read Model Second | Regenerable from files; resilient to per-file/per-row failure | ✅ PASS — partial records (FR-004a) and per-file resilience (SC-009) satisfy "parsing failures in one file MUST NOT block unrelated domains" |
| III. Native Over Generic | macOS-native; Finder-openable files | ✅ PASS — no new UI; files remain plain and externally editable |
| IV. Safe Writes Only | Backup, atomic, sync-gated, manual conflict, repair log | ✅ PASS — repair reuses Phase 1 backup/coordination/write-gate (FR-014, FR-016a); logs to repair-log.csv |
| V. Traceability Always | Every value traces to source file + row | ✅ PASS — `source_file`/`source_row` on every record (FR-003); issues carry source location (FR-008/009) |
| VI. Cross-Domain Visibility | `account_id` resolves to master registry | ✅ PASS — cross-file rules enforce `account_id`/`account_group_id` references (FR-008a) |
| VII. Repair When Safe | Deterministic, previewable, classified, confirmed | ✅ PASS — auto set only (FR-012), preview+confirm (FR-013), idempotent (FR-015), manual-only never auto-applied (FR-016) |
| File & Schema Conventions | `# schema_version` comment row; unified ledger; three-tier classification; `.finance-meta/` app-managed | ✅ PASS (with tracked deviation) — tolerant `#`-row parsing (FR-001), version routing (FR-005), R6 ledger fold (FR-020), `.finance-meta/` mirror not a source of truth. Migration ships as the `migrate-r6` SwiftPM executable (release-scoped, multi-file atomic rename); the per-file `Scripts/migrate-{file-type}-…` naming in the constitution predates the SwiftPM packaging + R6 release migration — see Complexity Tracking. |
| V1 Scope Boundaries | No deferred-scope features (no Markdown rendering, no AI, no sync) | ✅ PASS — Markdown metadata-only (FR-007); import sign-flip and UI explicitly out of Phase 2 |

**Result: PASS.** No violations. Complexity Tracking is empty.

**Post-design re-check (after Phase 1 artifacts)**: PASS — the unified issue stream (FR-009a) and partial-record model (FR-004a) reduce, not add, abstraction (one issue type, not two); bundled-authoritative schemas (FR-002) strengthen Principle II (the read model is fully app-regenerable and immune to workspace corruption) without introducing a database. No Complexity Tracking entries.

## Project Structure

### Documentation (this feature)

```text
specs/003-parsing-validation/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   ├── csv-schema-registry.md      # schema JSON shape + the full managed-file-type set
│   ├── validation-rule-catalog.md  # VAL-<TIER>-<NNN> rule shape + per-condition catalog
│   ├── parsing-contracts.md        # CSVParseResult / ParsedRecord / NormalizationError / NoteRecord
│   └── cli-scripts.md              # validate-workspace / repair-workspace / migrate-r6
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks output (NOT created here)
```

### Source Code (repository root)

Phase 2 touches the **bold** folders; the rest already exist from Phase 1 (`docs/architecture/core-domain.md §2`). The repo is a **Swift Package**, not an `.xcodeproj`.

```text
Sources/
  FinanceWorkspaceKit/
    Platform/              # Phase 1 (consumed, unchanged): FileIndexService, ManifestStore,
                           #   BackupService, FileCoordinatorService, WriteGate, providers
    Parsing/               # ← Phase 2 core
      CSVParserService.swift          (RFC-4180 + leading-# tolerance, header mapping)
      CSVSchemaRegistry.swift         (loads bundled schemas via Bundle.module)
      CSVNormalizer.swift             (typed values; partial records on bad fields)
      FrontMatterParser.swift         (--- delimited YAML block extractor)
      MarkdownParserService.swift     (NoteRecord; metadata-only, body unrendered)
    Validation/            # ← Phase 2: stubs made concrete + engine
      ValidationModels.swift          (ValidationIssue/RepairAction — now concrete)
      RuleCatalog.swift               (VAL-<TIER>-<NNN> rules as data)
      ValidationEngine.swift          (full-pass; lifts parse warnings into the issue stream)
      RepairService.swift             (auto-repair set; preview/backup/atomic/idempotent/log)
    Persistence/           # ← Phase 2
      ManifestStore.swift             (Phase 1, consumed)
      SettingsStore.swift             (Taxes/settings.csv → WorkspaceSettings observable)
    Domain/                # Phase 1 model types (consumed; minor wiring as records map to types)
    Resources/Schemas/     # ← Phase 2: bundled canonical JSON schemas (one per managed file type)
  FinanceWorkspaceApp/     # Phase 1 shell (detect-and-prompt migration wiring — minimal)
  validate-workspace/      # ← Phase 2 executable (main.swift)
  repair-workspace/        # ← Phase 2 executable (main.swift)
  migrate-r6/              # ← Phase 2 executable (main.swift)
Tests/
  FinanceWorkspaceKitTests/  # ← Phase 2: parser/normalizer/frontmatter/validation/repair/settings/migration
Package.swift              # ← Phase 2: add Parsing/Validation/Persistence sources are already in the
                           #   library; add `resources:` for Resources/Schemas + 3 new executable targets
workspace-template/.finance-meta/schemas/  # bootstrap mirror (seeded copy of bundled schemas)
.github/workflows/         # ci-macos.yml + swiftlint.yml (Phase 1)
```

**Structure Decision**: Continue the single Swift Package from Phase 1. Phase 2 adds the `Parsing/` services, the concrete `Validation/` engine + rules, `Persistence/SettingsStore`, the bundled `Resources/Schemas/` (declared in `Package.swift` via `resources:` so `Bundle.module` resolves them), and three new executable targets (`validate-workspace`, `repair-workspace`, `migrate-r6`). All Phase 1 services and domain models are consumed as-is. No web/mobile split; no `.xcodeproj` introduced in this phase.

## Complexity Tracking

> One tracked convention deviation (not a principle violation). Resolved by a separate constitution PATCH.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Migration named `migrate-r6` (SwiftPM executable) instead of the constitution's `Scripts/migrate-{file-type}-v{old}-to-v{new}.swift` | The R6 renames span three files + a ledger fold that must apply atomically as one release migration; the repo is a SwiftPM package (no `Scripts/*.swift` run target). | Per-file scripts can't express the interdependent atomic renames; the `Scripts/…swift` path doesn't exist under SwiftPM. Convention text predates both decisions — flagged for a `/speckit-constitution` PATCH, not silently diluted. |
