# Implementation Plan: Write Flows, Repair & Export (Phase 6)

**Branch**: `007-write-flows-repair-export` | **Date**: 2026-07-05 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/007-write-flows-repair-export/spec.md`

> Incorporates the `/speckit-clarify` Session 2026-07-05 decisions: import assigns **one
> user-selected target account** to every row; duplicate rows are **flagged in the import preview**
> (matched on date + amount + description within the target account) for per-row include/exclude;
> the **⌘N "add new record"** action is **context-sensitive** to the active module; **portfolios and
> sleeves** join the structured-editable set; the in-app **"Close Tax Year"** action is in scope,
> wired through the safe-write path over the existing Phase-4 archive write.

## Summary

Make the read-only Phase-5 app **writable**. Introduce one Kit-level write engine that turns a user
edit/import/repair/delete intent into a previewable **WritePlan**, applies it through the existing
Phase-1 safe-write primitives (`BackupService` → `WriteGate` → `FileCoordinatorService` atomic
apply → repair/write log), and triggers a `ProjectionStore` re-index + re-validate. The UI adds the
edit/delete affordances (already stubbed as disabled in `DetailPaneView` and `AppCommands`), the
import column-mapping flow, the reassignment picker, the repair-apply wiring, and export.

- **Write engine** (`FinanceWorkspaceKit/Persistence/Write/`): the phase's core, all CI-testable on
  the CLT-only box.
  - `WritePlan` — the previewable, atomic unit: target file(s), row-level diffs (add/modify/delete),
    referencing rows + reassignments (delete), derived values, and the backup reference.
  - `CSVRowSerializer` — the **reverse of `RecordMappers`**: typed entity → canonical CSV row,
    preserving column order, the leading `# schema_version: N` comment, and the amount sign
    convention. Round-trips (`parse → serialize`) byte-stably for unchanged rows (SC-003).
  - `WriteService` — orchestrates preview → `WriteGate` check → backup every touched file → atomic
    coordinated write → log. Never reimplements backup/coordination (FR-002); it composes the
    Phase-1 primitives exactly as `TaxSafeWrite` already demonstrates.
  - `ReferenceScanner` — builds the FK reference graph across all collections so a delete surfaces
    every referencing row grouped by collection, and validates that a reassignment target is not
    itself deleted in the same plan (FR-019–FR-022).
  - `ImportMapper` — auto-detects an external-CSV → canonical column mapping, applies the confirmed
    sign convention, splits rows by `YYYY-MM`, assigns the chosen target account, and flags
    duplicates (date + amount + description within the account).
  - `ExportService` — current-view rows → CSV with `source_file`/`source_row` provenance columns;
    Budget month → Markdown summary (period header + category breakdown).
- **UI write surfaces** (`FinanceWorkspaceApp/UI/`): per-entity edit forms reached from the two
  documented placement points — right-panel `.editForm` surface (edit/delete at panel bottom) and
  dedicated-screen local actions (delete inside edit); the `WritePreviewView` (before/after diff +
  backup location + apply/cancel) shared by every write; the `ImportView` two-step column-mapping
  flow; the `ReassignmentPicker`; the multi-entry `TransactionGroupEditor`; the repair-apply wiring
  in `OverviewIssuesTableView`/`DetailPaneView`; and the `ExportService` save-panel command.
- **Command + gate wiring**: enable ⌘E (export) and ⇧⌘R (repair apply), add the context-sensitive
  ⌘N add-record action, and extend `CommandMatrix` accordingly; every write affordance is
  additionally gated live by `WriteGate` on the target file's sync state.

Technical approach: the write engine lives entirely in `FinanceWorkspaceKit` (pure, `swift test`-able
in CI) so the CLT-only dev box builds and the App target holds only SwiftUI forms. Every mutation is
one `WritePlan` applied atomically; nothing bypasses the preview → backup → apply → re-index path
(FR-001). Every new/changed view clears the `design-adherence` gate.

## Technical Context

**Language/Version**: Swift 6; SwiftUI (`@Observable`, `.inspector`, `.commands`, `fileImporter`/
`fileExporter`) — macOS-15 SDK, no third-party dependencies.
**Primary Dependencies**: the merged `FinanceWorkspaceKit` — `BackupService`,
`FileCoordinatorService`, `WriteGate`, `ManifestStore` (drift check), `CSVParserService`/
`CSVSchemaRegistry`/`CSVNormalizer` (import + serialization), `RecordMappers` (read seam; the new
serializer is its inverse), `ValidationEngine`/`RuleCatalog`/`RepairService` (reference checks,
repair `plan()`/`apply()`, re-validation), `WorkspaceLayout` (canonical paths/seeds),
`TaxPrepEngine`/`TaxSafeWrite` (year-close archive write, reused), and the App's `ProjectionStore`
(re-index) + `AppState`/`AppRouter` (surfaces).
**Storage**: canonical CSV/Markdown files only — this phase *writes* them. No new store; backups in
`.finance-meta/backups/`, log in `.finance-meta/logs/repair-log.csv` (both existing). Exports are
written outside the workspace to a user-chosen destination.
**Testing**: Swift Testing in macOS CI — `CSVRowSerializer` round-trip/byte-stability,
`WriteService` backup-before-write + atomic-failure-leaves-original + sync-gate-block,
`ReferenceScanner` reference graph + reassignment validity, `ImportMapper` auto-detect/month-split/
duplicate-flag/sign-convention, multi-entry reconciliation + atomic group write/delete, repair apply
→ re-validate clears the issue, `ExportService` provenance columns + Markdown shape, `CommandMatrix`
updated enable/disable. Fixture writes go to a temp workspace (never the dev workspace). SwiftLint
`--strict` on the Linux runner.
**Target Platform**: macOS 15 (Sequoia)+.
**Project Type**: Native macOS desktop app — SwiftPM package (`FinanceWorkspaceKit` library +
`FinanceWorkspaceApp` executable); the Phase-5 XcodeGen app wrapper is unaffected.
**Performance Goals**: a write + targeted re-index feels immediate on a 12-month fixture workspace;
re-index reuses the Phase-5 off-main-actor `ProjectionStore` build. Hard numeric thresholds remain a
Phase-7 concern (roadmap).
**Constraints**: every mutation via the single safe-write path (FR-001); reuse Phase-1 primitives,
never reimplement (FR-002, constitution P-IV); atomic all-or-nothing per plan including multi-entry
groups and delete-with-reassignment (SC-003); writes blocked and reasoned while a target file is
syncing/stale/conflicted (FR-005/SC-008); deterministic previewable repairs only (P-VII); no new
persistent store (P-I/II); all forms clear `design-adherence` and use `DesignSystem` tokens.
**Observability**: every write/repair appends to `repair-log.csv`; post-write validation refreshes
the header issues chip + Overview table; `WriteGate` reasons surface inline on disabled affordances.
**Scale/Scope**: single user/workspace; 12 editable entity types + import + multi-entry editor +
delete-reassign + repair-apply + export + tax-year-close; 30 base FRs plus the six clarified
sub-requirements (FR-011a/012a/015a/030a), 6 user stories.

No open `NEEDS CLARIFICATION` — the material ambiguities were resolved across the two 2026-07-05
clarify sessions; remaining plan-level choices (write-plan shape, serializer fidelity, drift
detection, reassignment scan, import heuristics, export format) are decided in `research.md` D1–D10.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* — Source:
`.specify/memory/constitution.md` v1.1.1.

| Principle / Section | Gate | Status |
|---|---|---|
| I. Plain Files First | No hidden primary DB; every writable entity has a file representation | ✅ PASS — writes go straight to canonical CSV/Markdown; no new store; the in-memory `ProjectionStore` stays non-authoritative and is rebuilt from files after each write |
| II. Read Model Second | Projections regenerable; per-file resilience; provenance distinguished | ✅ PASS — post-write re-index rebuilds projections from files (FR-008); an edited value is re-derived, not held; `ValueProvenanceLabel` already marks imported/derived/repaired/user-edited |
| III. Native Over Generic | macOS conventions; keyboard nav; collapsible right pane | ✅ PASS — forms use native `fileImporter`/`fileExporter`/save panels, ⌘N/⌘E/⇧⌘R menu commands, and the existing `.inspector` edit surface; no cross-platform abstraction |
| IV. Safe Writes Only | Backup + preview + atomic + sync-gated + logged | ✅ PASS — this phase *is* P-IV: FR-001–FR-008 map 1:1 to timestamped backup, before-apply preview, atomic temp-then-rename, `WriteGate` sync block, and `repair-log.csv` logging, all via the reused Phase-1 primitives |
| V. Traceability Always | KPI → detail → source; paths/timestamps visible | ✅ PASS — the write preview names the exact target file + row; exports carry `source_file`/`source_row`; the inspector is unchanged |
| VI. Cross-Domain Visibility | Shared registry; links maintained | ✅ PASS — deletes run the cross-collection `ReferenceScanner` (registry-aware); reassignment keeps `account_id`/`category_id`/`account_group_id` FKs valid; import assigns a registry account |
| VII. Repair When Safe | Deterministic, previewable, confirmed, classified, logged | ✅ PASS — repair *apply* reuses `RepairService` (auto/manual classification already enforced; manual-only never offered, FR-025); confirm-after-diff (FR-024); logged |
| File & Schema Conventions | schema_version comment rows; unified ledger; `.finance-meta/` app-managed; migrations for breaking changes | ✅ PASS — serializer preserves the leading `# schema_version: N` row and canonical columns; transactions written to the unified `Accounts/transactions/YYYY-MM.csv` with `group_id` grouping; **no schema change** → no migration |
| V1 Scope Boundaries | No deferred-scope features; tax = estimates | ✅ PASS — no bank/brokerage *sync* (manual CSV import only), no budget-rule automation, no Notes/Issues/Files, no xlsx; import/export are file operations; tax stays estimation-only (year-close archives estimates) |

**Result: PASS.** No violations. Complexity Tracking is empty.

**Post-design re-check (after Phase 1 artifacts)**: PASS — the design adds exactly one new Kit
sub-layer (`Persistence/Write/`) that *composes* existing primitives rather than introducing a
parallel write path, plus thin SwiftUI forms. The `WritePlan` abstraction is required so preview,
backup, and atomic apply share one representation (P-IV); it is not an extra layer between engines
and files but the safe-write contract itself. No Complexity Tracking entries.

## Project Structure

### Documentation (this feature)

```text
specs/007-write-flows-repair-export/
├── plan.md              # This file
├── research.md          # Phase 0 — D1 WritePlan model, D2 CSV serializer fidelity, D3 reference
│                        #   scan/reassign, D4 import mapping + duplicate flag, D5 multi-entry atomic,
│                        #   D6 repair-apply wiring, D7 export formats, D8 drift detection, D9 command
│                        #   /gate wiring, D10 edit-form generation strategy
├── data-model.md        # Phase 1 — WritePlan/RowDiff/ReferenceGroup/Reassignment/ColumnMapping/
│                        #   ImportBatch/ExportRequest + per-entity write targets
├── quickstart.md        # Phase 1 — exercise each write flow against a temp fixture workspace; CI notes
├── contracts/
│   ├── write-engine.md          # WriteService/WritePlan/CSVRowSerializer/ReferenceScanner Kit API
│   ├── import-export.md         # ImportMapper + ExportService contracts
│   ├── ui-write-flows.md        # edit-form/preview/reassign/import/multi-entry UI ⇄ engine contracts
│   └── commands.md              # updated CommandMatrix + ⌘N/⌘E/⇧⌘R wiring + WriteGate affordance gating
├── checklists/requirements.md   # /speckit-specify output (validated)
└── tasks.md             # /speckit-tasks output (NOT created here)
```

### Source Code (repository root)

Phase 6 adds the **bold** paths; everything else is consumed unchanged (any engine gap found is a
followup, not an in-form computation).

```text
Sources/
  FinanceWorkspaceKit/
    Platform/                        # consumed: BackupService, FileCoordinatorService, WriteGate, ManifestStore
    Parsing/                         # consumed: CSVParser/SchemaRegistry/Normalizer (import + serialize)
    Validation/                      # consumed: ValidationEngine, RepairService (apply)
    Domain/Mapping/RecordMappers.swift  # consumed: read seam (serializer is its inverse)
    Domain/Taxes/TaxSafeWrite.swift     # consumed: year-close archive write pattern (reused)
    Persistence/
      Write/                         # ← NEW: the write engine (all CI-testable)
        WritePlan.swift              #   plan model: targets, RowDiff[], reference groups, reassignments, backup ref
        CSVRowSerializer.swift       #   typed entity → canonical CSV row (inverse of RecordMappers)
        WriteService.swift           #   preview → WriteGate → backup → atomic apply → log (composes Phase-1 primitives)
        ReferenceScanner.swift       #   FK reference graph; reassignment-target validity
        ImportMapper.swift           #   auto-detect mapping, sign convention, month-split, duplicate flag
        ExportService.swift          #   CSV(+provenance) / Markdown budget summary
  FinanceWorkspaceApp/
    UI/
      Shell/AppCommands.swift        # ← edited: enable Export/Repair-apply, add ⌘N add-record
      Shell/DetailPaneView.swift     # ← edited: .editForm reachable; enable panel-bottom Edit/Delete
      Write/                         # ← NEW: cross-cutting write UI
        WritePreviewView.swift       #   before/after diff + backup location + apply/cancel (shared)
        ReassignmentPickerView.swift #   per-collection reassignment on delete
        ImportView.swift             #   two-step column-mapping import flow (file → mapping → preview)
        TransactionGroupEditor.swift #   multi-entry add/edit/delete (atomic group)
        EntityEditForms.swift        #   per-entity forms (account/group/category/budget/allocation/
                                     #     goal/asset/liability/portfolio/sleeve/tax-adjustment/rule)
      Taxes/CurrentTaxYearView.swift # ← edited: wire "Close Tax Year" action → preview → archive write
      Overview/OverviewIssuesTableView.swift # ← edited: repair apply (preview → confirm → apply)
    AppState.swift                   # ← edited: pending-WritePlan + import/edit sheet state; post-write re-index hook
Tests/
  FinanceWorkspaceKitTests/          # ← + WriteServiceTests, CSVRowSerializerTests, ReferenceScannerTests,
                                     #     ImportMapperTests, ExportServiceTests, MultiEntryWriteTests
  FinanceWorkspaceAppTests/          # ← + CommandMatrixTests (updated), WritePreview/ImportView VM tests
Package.swift                        # unchanged (Write/ is inside FinanceWorkspaceKit)
docs/out-of-scope-followups.md       # ← updated on completion
docs/test-plans.md                   # ← updated on completion (write-flow user flows now testable)
```

**Structure Decision**: The write engine lives in `FinanceWorkspaceKit/Persistence/Write/` so all
mutation logic (plan building, serialization, reference scanning, import, export) is pure and
`swift test`-able in CI on the CLT-only box, mirroring how `RepairService`/`TaxSafeWrite` already sit
in the Kit. The App target holds only SwiftUI forms that build a `WritePlan` and hand it to
`WriteService`. This keeps the five-layer model intact (forms depend on the write engine; the engine
composes Phase-1 primitives) and adds no new abstraction between engines and files beyond the
`WritePlan` safe-write contract itself.

## Complexity Tracking

> No constitution violations — table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
