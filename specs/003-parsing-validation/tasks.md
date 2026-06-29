---
description: "Task list for Parsing, Validation & Infrastructure (Phase 2)"
---

# Tasks: Parsing, Validation & Infrastructure (Phase 2)

**Input**: Design documents from `specs/003-parsing-validation/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included — the spec is verification-heavy (9 success criteria, per-story Independent Tests, quickstart scenarios). Test tasks map to acceptance criteria; written alongside their story, not strict TDD-first (matches the `002` precedent).

**Organization**: Tasks are grouped by user story. The stories are largely independent once the shared schemas + types exist, but form a natural read-pipeline order (parse → validate → repair → settings → migrate), so they are sequenced by priority.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1–US5 maps to the spec's user stories
- Paths are relative to repo root. This is a **Swift Package**: library code lives under `Sources/FinanceWorkspaceKit/{Parsing,Validation,Persistence}/`; executables under `Sources/{validate-workspace,repair-workspace,migrate-r6}/`; tests under `Tests/FinanceWorkspaceKitTests/` (Swift Testing, `import Testing`).

> **Continuity note:** Phase 1 (`002`) is merged. Phase 2 consumes its services (`FileIndexService`, `ManifestStore`, `BackupService`, `FileCoordinatorService`, `WriteGate`, providers) and domain models unchanged, and makes the Phase 1 `ValidationIssue`/`RepairAction` stubs concrete. Schemas are **bundled** with the app (clarify Q2) and mirrored into the workspace at bootstrap.

---

## Phase 1: Setup (Package & structure)

**Purpose**: Wire the SwiftPM package for bundled schema resources, the new executables, and the `Parsing/` source folder.

- [X] T001 [P] Add `Sources/FinanceWorkspaceKit/Resources/Schemas/` and declare `resources: [.copy("Resources/Schemas")]` on the `FinanceWorkspaceKit` target in `Package.swift` (enables `Bundle.module` schema loading)
- [X] T002 [P] Add three executable targets — `validate-workspace`, `repair-workspace`, `migrate-r6` — each with a `Sources/<exe>/main.swift` stub depending on `FinanceWorkspaceKit`, in `Package.swift`
- [X] T003 [P] Create the `Sources/FinanceWorkspaceKit/Parsing/` folder and confirm `Validation/` + `Persistence/` exist

**Checkpoint**: `swift build` succeeds with empty stubs; `Bundle.module` resolves the (empty) Schemas resource.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Author the bundled schemas and the shared parsing/validation types every user story depends on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T004 Author the bundled canonical JSON schemas — **one per managed file type** (account-groups, accounts, liabilities, account-rules, transactions, categories, budgets, budget-allocations, goals, savings-progress, assets, prices, dividends, tax-lots, portfolios, sleeves, sleeve-targets, benchmark-series, tax-adjustments, tax-estimates, tax-documents, estimated-payments, settings) including full enum value sets (`account_group`, `account_type`, `trade_type`, `frequency`, `adjustment_type`, `status`) and required/optional flags — in `Sources/FinanceWorkspaceKit/Resources/Schemas/` per `contracts/csv-schema-registry.md` and `docs/architecture/containers-and-budgets.md §3` (extends the Phase 1 `account`/`transaction` starters; resolves R6-M1…M4)
- [X] T005 Mirror the bundled schema set into `workspace-template/.finance-meta/schemas/` and confirm `bootstrap-workspace` seeds the full set with `# schema_version: 1`
- [X] T006 [P] Define parsing model types (`ColumnType`, `ColumnDefinition`, `CSVSchema`, `FieldValue`, `ParsedRecord`, `ParseWarning`/`NormalizationError`, `CSVParseResult`, `FrontMatterValue`, `FrontMatter`, `NoteRecord`) in `Sources/FinanceWorkspaceKit/Parsing/ParsingModels.swift` per `data-model.md`
- [X] T007 [P] Make the Phase 1 stubs concrete — enums `RuleTier`/`Severity`/`RepairClass`, `ValidationRule`, `ValidationIssue`, `ValidationResult`, `RepairAction`, `RepairPlan`, `RowDiff`, `RepairLogEntry` — in `Sources/FinanceWorkspaceKit/Validation/ValidationModels.swift` per `data-model.md`
- [X] T008 Define `WorkspaceContext` (aggregate of parsed `CSVParseResult`s + `NoteRecord`s + resolved id registries for cross-file lookups) in `Sources/FinanceWorkspaceKit/Validation/WorkspaceContext.swift`

**Checkpoint**: Schemas exist as bundled resources; shared types compile — story work can begin.

---

## Phase 3: User Story 1 — Files become typed domain records (Priority: P1) 🎯 MVP

**Goal**: Turn every managed CSV/Markdown file into typed records with source provenance; bad fields yield partial records, never dropped rows.

**Independent Test**: Parse a realistic fixture → every managed file type yields typed records with `source_file`/`source_row`; a bad date/decimal/enum becomes a flagged partial record + warning; every note yields front-matter metadata.

- [X] T009 [P] [US1] Test: every managed file type in a valid fixture parses into typed records with provenance, zero crashes (SC-001) in `Tests/FinanceWorkspaceKitTests/ParsingTests.swift`
- [X] T010 [P] [US1] Test: an unconvertible date/decimal/enum yields a **partial record** (field nulled+flagged, row retained) plus a warning naming file/row/column (FR-004a, SC-009) in `Tests/FinanceWorkspaceKitTests/NormalizationTests.swift`
- [X] T011 [P] [US1] Test: case/whitespace-variant headers map to canonical columns; leading `#`/`# schema_version` row stripped; RFC-4180 quoted fields with embedded commas/newlines (FR-001) in `Tests/FinanceWorkspaceKitTests/CSVParserTests.swift`
- [X] T012 [P] [US1] Test: Markdown front matter → typed `NoteRecord`; missing/malformed front matter handled gracefully (FR-006, FR-007, SC-002) in `Tests/FinanceWorkspaceKitTests/MarkdownParsingTests.swift`
- [X] T013 [US1] Implement `CSVSchemaRegistry` — load bundled schemas via `Bundle.module`; classify by path→filename→header; resolve `schema_version` and route older versions to migration/repair; missing marker → current + flag (FR-002, FR-005) in `Sources/FinanceWorkspaceKit/Parsing/CSVSchemaRegistry.swift`
- [X] T014 [US1] Implement `CSVParserService` — RFC-4180 parsing, leading-`#` tolerance, case-insensitive/trimmed header mapping, `source_file`/`source_row` provenance, resilient per-row (FR-001, FR-003, SC-009) in `Sources/FinanceWorkspaceKit/Parsing/CSVParserService.swift`
- [X] T015 [US1] Implement `CSVNormalizer` — `Decimal`/`Date`(ISO 8601)/`Bool`/`Int`/enum conversion; **partial record** on failure; blank-field handling; never flips amount signs (FR-004, FR-004a) in `Sources/FinanceWorkspaceKit/Parsing/CSVNormalizer.swift`
- [X] T016 [US1] Implement `FrontMatterParser` — extract the `---` block into flat metadata; graceful on missing/malformed (FR-006) in `Sources/FinanceWorkspaceKit/Parsing/FrontMatterParser.swift`
- [X] T017 [US1] Implement `MarkdownParserService` — produce `NoteRecord` (classify by `type` + folder; linked IDs/period/tax year; body preserved, unrendered) (FR-007) in `Sources/FinanceWorkspaceKit/Parsing/MarkdownParserService.swift`
- [X] T018 [US1] Implement `WorkspaceParser` — workspace-wide parse pass (read via `FileCoordinatorService`, resilient per-file) producing the parsed set that feeds `WorkspaceContext` in `Sources/FinanceWorkspaceKit/Parsing/WorkspaceParser.swift`

**Checkpoint**: Files become typed records — the Phase 2 MVP. Every Phase 3/4 engine can now read data.

---

## Phase 4: User Story 2 — Validation & classified issues (Priority: P2)

**Goal**: Full-workspace validation across three tiers, emitting a single unified issue stream classified by severity + repair class.

**Independent Test**: Valid fixture ⇒ zero errors/false-positives; defect-seeded fixture ⇒ each rule fires once with correct id/tier/severity/repair-class; parse warnings appear in the same stream.

- [X] T019 [P] [US2] Test: valid fixture ⇒ zero errors and zero false-positive warnings (SC-003) in `Tests/FinanceWorkspaceKitTests/ValidationTests.swift`
- [X] T020 [P] [US2] Test: defect-seeded fixture ⇒ each rule fires exactly once with correct `VAL-<TIER>-<NNN>` id, tier, severity, repair class (SC-003) in `Tests/FinanceWorkspaceKitTests/ValidationCatalogTests.swift`
- [X] T021 [P] [US2] Test: parse/normalization warnings surface in `ValidationResult` as file-level issues (unified stream, FR-009a) in `Tests/FinanceWorkspaceKitTests/UnifiedIssueStreamTests.swift`
- [X] T022 [US2] Implement `RuleCatalog` — one rule per condition with `VAL-<TIER>-<NNN>` ids + the locked classification defaults, per `contracts/validation-rule-catalog.md`, in `Sources/FinanceWorkspaceKit/Validation/RuleCatalog.swift` (resolves the open "validation rule catalog" item)
- [~] T023 [P] [US2] File-level rule predicates in `Sources/FinanceWorkspaceKit/Validation/Rules/FileRules.swift` — missing-required-file (001), unknown-file-type (002), invalid monthly-ledger name (003) wired; invalid header/date/decimal/enum/missing-front-matter arrive via lifted parse warnings. **Pending**: duplicate monthly file (004).
- [~] T024 [P] [US2] Cross-file rule predicates in `Sources/FinanceWorkspaceKit/Validation/Rules/CrossFileRules.swift` — generic reference checks (001..008), duplicate transaction ID (010), orphan note link (011) wired; delete-with-reference is lookups-only by design (clarify N1). **Pending**: missing benchmark data (009).
- [~] T025 [P] [US2] Domain rule predicates in `Sources/FinanceWorkspaceKit/Validation/Rules/DomainRules.swift` — asset-without-account (003), trade-without-asset (004), balanced-group net-zero (005), gross/net reconciliation (006) wired. **Pending**: budget-period-without-rows (001), goal-contribution-without-goal (002 — largely covered by CROSS-008), tax-payment-outside-year (007), business-txn-unknown-group (008).
- [X] T026 [US2] Implement `ValidationEngine.validate(_:)` — full pass (file→cross-file→domain), group by severity, **lift parse warnings** into the issue stream, no false positives on sparse data (FR-009, FR-009a, FR-009b, FR-010, FR-011) in `Sources/FinanceWorkspaceKit/Validation/ValidationEngine.swift`

**Checkpoint**: The workspace is validated, every issue classified, in one unified stream.

---

## Phase 5: User Story 3 — Safe, previewable auto-repair + dev CLIs (Priority: P3)

**Goal**: Deterministic auto-repair (preview → backup → atomic → log → idempotent) for the auto set only, exposed via the `validate-workspace` / `repair-workspace` CLIs.

**Independent Test**: Introduce each repairable defect → preview shows a diff and writes nothing → apply fixes it, backs up, logs → re-apply is a no-op; a manual-only issue is never touched.

- [X] T027 [P] [US3] Test: each repairable defect → correct fix + `repair-log.csv` entry; second apply is a verified no-op (SC-004) in `Tests/FinanceWorkspaceKitTests/RepairTests.swift`
- [X] T028 [P] [US3] Test: a manual-only issue is never modified by auto-repair (SC-005) in `Tests/FinanceWorkspaceKitTests/RepairManualOnlyTests.swift`
- [X] T029 [P] [US3] Test: preview mode produces a before/after diff and writes nothing (FR-013) in `Tests/FinanceWorkspaceKitTests/RepairPreviewTests.swift`
- [~] T030 [US3] `RepairService` in `Sources/FinanceWorkspaceKit/Validation/RepairService.swift` — create-missing-folder, create-missing-seed-file, and **normalize-header-casing** (CSV-rewrite) wired, with preview diff, backup-before-modify, atomic apply, idempotency, repair-log, never-touch-manual-only (FR-012/013/014/015/016). **Pending**: optional-column injection (deferred by design — proactively injecting absent optional columns would flag clean files; needs an "expected columns" notion), blank-field normalization, and `WriteGate` sync-gating wiring (FR-016a, provider layer).
- [X] T031 [US3] Implement `validate-workspace` executable — full pass, grouped-by-severity summary, non-zero exit on errors, per `contracts/cli-scripts.md`, in `Sources/validate-workspace/main.swift` *(--json/--report pending)*
- [X] T032 [US3] Implement `repair-workspace` executable — `--dry-run` (diff only) / `--apply` (log), idempotent, per `contracts/cli-scripts.md`, in `Sources/repair-workspace/main.swift`

**Checkpoint**: The workspace is self-healing for the auto set, with developer CLIs.

---

## Phase 6: User Story 4 — Typed workspace settings (Priority: P4)

**Goal**: `Taxes/settings.csv` → observable typed `WorkspaceSettings`, with defaults and a safe write-back path.

**Independent Test**: Read typed settings from a fixture; delete the file → typed defaults; change a setting → backed-up atomic write → re-reads identically.

- [X] T033 [P] [US4] Test: settings round-trip — read typed; missing file → typed defaults; change re-reads identically (SC-006) in `Tests/FinanceWorkspaceKitTests/SettingsStoreTests.swift`
- [X] T034 [US4] Implement `SettingsStore` — read/write `Taxes/settings.csv` → `@Observable WorkspaceSettings` (filing status, tax year, currency, timezone); typed defaults when absent; backed-up, atomic, sync-gated write (FR-017) in `Sources/FinanceWorkspaceKit/Persistence/SettingsStore.swift`

**Checkpoint**: Typed, observable settings available to downstream phases.

---

## Phase 7: User Story 5 — One-time R6 migration (Priority: P5)

**Goal**: Detect-and-prompt, previewable, lossless migration of pre-R6 workspaces; no-op on R6-native.

**Independent Test**: Synthetic pre-R6 fixture → preview shows a full change plan (no writes) → apply renames files/columns, folds investment transactions into the unified ledger as `trade` rows, seeds new files, bumps `schema_version`, updates manifest → re-run is a no-op.

- [ ] T035 [P] [US5] Test: synthetic pre-R6 fixture migrates losslessly (renames, ledger fold to `trade` rows, seeds, version bump, manifest update); re-run is a no-op (SC-008) in `Tests/FinanceWorkspaceKitTests/MigrationTests.swift`
- [ ] T036 [US5] Add a synthetic **pre-R6** fixture path (legacy `entities`/`holdings`/`deductions` names + a separate `Investments/transactions.csv`) to `fixture-generate` or a test fixture builder
- [ ] T037 [US5] Implement `migrate-r6` executable — detect pre-R6; `--dry-run` change plan; `--apply` atomic+backed-up renames (`entities`→`account-groups`/`entity_id`→`account_group_id`, `holdings`→`assets`/`holding_id`→`asset_id`, `deductions`→`tax-adjustments`/`deduction_id`→`tax_adjustment_id`), fold `Investments/transactions.csv` → unified ledger `type = trade` rows by date, seed new files, bump `schema_version`, update manifest; no-op on R6-native (FR-020), per `contracts/cli-scripts.md`, in `Sources/migrate-r6/main.swift` (resolves R6-M5)
- [ ] T038 [US5] Wire **detect-and-prompt** into the app shell — surface pre-R6 detection and offer the previewable migration; never auto-apply (FR-020a) in `Sources/FinanceWorkspaceApp/`

**Checkpoint**: Prototype-era workspaces can be migrated; fresh workspaces are unaffected.

---

## Phase 8: Polish & Cross-Cutting Concerns

- [ ] T039 [P] Run the `quickstart.md` verification table end-to-end against the fixtures
- [ ] T040 [P] Unit tests for `Decimal`/ISO-8601 normalization edge cases, RFC-4180 quoting, and front-matter edge cases in `Tests/FinanceWorkspaceKitTests/Unit/`
- [ ] T041 Responsive parse + full-validate sanity check on the 12-month fixture (SC-002 soft target; hard thresholds deferred to roadmap Phase 7)
- [ ] T042 [P] Update `CLAUDE.md` build/test notes if the new executables/Parsing services change run commands
- [ ] T043 Confirm the **Milestone 2** gate: every supported file type parses into typed records; the engine detects + classifies all defined issue types; auto-repairs apply with preview; fixtures for all file types pass parsing cleanly

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (P1)** → **Foundational (P2)** → user stories. Foundational (schemas + shared types) blocks everything.
- **Story order**: US1 (parsing) is the prerequisite for US2 (validation consumes parsed records) and US5 (migration reuses parse/normalize). US3 (repair) depends on US2 (it acts on classified issues). US4 (settings) depends only on parsing + the safe-write primitives, so it can proceed in parallel with US2/US3 after US1. US5 depends on US1 + the schema set.
- Build order: **US1 → US2 → US3**, with **US4** parallelizable after US1, and **US5** after US1 (+ schemas). **Polish (P8)** last.

### Within-story parallelism

- Foundational model tasks T006/T007 are `[P]` (different files); T004 (schemas) and T008 (`WorkspaceContext`) are sequential anchors.
- US2 rule predicate files T023/T024/T025 are `[P]` (different files) once `RuleCatalog` (T022) defines the shapes; `ValidationEngine` (T026) integrates them.
- All `[P]` test tasks within a story run in parallel.

---

## Parallel Example: US2 rule predicates

```bash
# After T022 (RuleCatalog), implement the three predicate files together:
Task: "T023 File-level rule predicates in Validation/Rules/FileRules.swift"
Task: "T024 Cross-file rule predicates in Validation/Rules/CrossFileRules.swift"
Task: "T025 Domain rule predicates in Validation/Rules/DomainRules.swift"
```

---

## Implementation Strategy

### MVP first (US1)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → **STOP & VALIDATE**: every managed file type parses into typed records with provenance, bad fields become flagged partial records (SC-001, SC-009). This is the demoable MVP floor — the read pipeline the domain engines need.

### Incremental delivery

US1 (files → records) → US2 (validated + classified) → US3 (self-healing + CLIs) → US4 (typed settings, parallelizable) → US5 (legacy migration) → Polish (quickstart + Milestone 2 gate).

---

## Notes

- `[P]` = different files, no dependencies; `[Story]` = traceability to spec user stories.
- Tests map to the spec's Success Criteria (SC-001…SC-009) and the clarified behaviors (FR-004a partial records, FR-009a unified stream, FR-013 preview, FR-020 migration).
- Repair, settings, and migration writes all reuse the Phase 1 `BackupService`/`FileCoordinatorService`/`WriteGate` — do not reimplement safe-write logic.
- Commit after each task or logical group; stop at any checkpoint to validate a story.
- Milestone 2 (T043) is the Phase 2 exit gate.
