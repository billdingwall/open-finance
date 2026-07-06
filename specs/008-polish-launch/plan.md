# Implementation Plan: Polish & Launch Readiness (Phase 7)

**Branch**: `008-polish-launch` | **Date**: 2026-07-06 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/008-polish-launch/spec.md`

> Incorporates the three `/speckit-clarify` sessions (2026-07-06): perf targets **≤2s cold-launch /
> ≤5s re-index**; **Developer ID + notarization** (no App Store this phase); backup retention **last
> 10 per file + 30 days**, pruned **after each write and on launch**; **single spec** (all six user
> stories here); **require iCloud** at first launch (no local-folder fallback — keeps the provider
> dev-only); **manual pick-a-version** conflict resolution; **full structural** multi-entry group
> editing with all legs in **one monthly file** and **whole-group** ledger edit/delete.

## Summary

Make the merged v1 app **launch-ready**. This phase adds **no new product surface** beyond finishing
the Phase-6 write flows; it (1) surfaces and completes the write experience, then (2) hardens the app
for distribution, performance, reliability, accessibility, native behavior, and test coverage.

- **US1 — write-affordance enablement (DELIVERED this session).** The visible Import/Add/Edit
  page-title actions, the sidebar "New group", and the empty-state CTAs are now live and sync-gated;
  the previously-absent **Edit account group** action was added. Only a runtime `WriteGate` block
  disables a write action (with its reason as a tooltip). Remaining US1 work is the App-target
  view-model tests + a smoke test asserting no permanently-disabled write button.
- **US2 — finish deferred write flows.** Build the multi-entry `TransactionGroupEditor` (all legs in
  one monthly file, whole-group ledger edit/delete, live reconciliation) and the per-collection
  `ReassignmentPickerView`, wire the Budget Markdown-summary export button, layer **typed** entity
  edit controls over the schema-driven form (grouped parent pickers, sign-aware amounts, enum
  pickers), and add the one additive schema touch — an optional `transactions.description` column so
  imported memos are retained and duplicate detection keys on date + amount + description.
- **US3 — signed, installable, iCloud-syncing build.** Configure Developer ID signing + notarization
  on the XcodeGen app target (entitlement already attached), and implement the manual pick-a-version
  conflict-resolution surface over `NSFileVersion`.
- **US4/US5 — performance, reliability, accessibility, native.** Projection caching keyed by file
  hashes, off-main-thread parse/validate, `FileWatcherService` debounce, lazy view loading, and a
  measurement harness proving ≤2s/≤5s; last-known-valid projection during re-index; sparse-data
  resilience; VoiceOver labels + WCAG AA contrast; keyboard-nav audit; `NSUserActivity` restoration
  verified in the signed app; `.csv`/`.md` drag-and-drop; the full menu set incl. Open Backup Folder;
  require-iCloud first-launch onboarding.
- **US6 — test & QA hardening.** One valid + one invalid fixture per managed file type; integration
  tests for read/write/repair; XCUITest smoke of every module view; and a backup-prune routine
  (last-10 + 30-day, pruned after write + on launch, never removing a backup an in-flight write needs).

Technical approach: reuse everything already merged. The write **engines** (multi-entry
reconciliation, reference scan/reassign, export-Markdown, repair) shipped and are unit-tested in
Phase 6 — this phase wires their **UI**, adds the one optional column, and layers hardening. Signing
and real iCloud sync exercise the Phase-5 XcodeGen app target on real hardware. Every new/changed
view clears the `design-adherence` gate; every mutation still flows through the single `WriteService`
safe-write path (never reimplemented).

## Technical Context

**Language/Version**: Swift 6; SwiftUI (`@Observable`, `.inspector`, `.commands`, `fileImporter`/
`fileExporter`, `NSUserActivity`, `onDrop`/`UTType`) — macOS-15 SDK, no third-party dependencies.
**Primary Dependencies**: the merged tree — `WriteService`/`WritePlan`/`CSVRowSerializer`/
`MultiEntry`/`ReferenceScanner`/`ImportMapper`/`ExportService` (Phase-6 write engine, reused),
`BackupService`/`FileCoordinatorService`/`WriteGate`/`ManifestStore` (safe-write primitives + hash
drift), `CSVSchemaRegistry`/`CSVNormalizer` (the optional-column add + dedup), `ProjectionStore` +
`AppState`/`AppRouter` (re-index, caching, restoration), `RepairService`/`ValidationEngine`
(hardening tests), `ICloudContainerService` (`NSMetadataQuery` sync state, `NSFileVersion`
conflicts), and the **XcodeGen app target** `App/project.yml` (signing/notarization).
**Storage**: canonical CSV/Markdown only — **one additive, optional column** (`transactions.description`,
non-breaking, no migration). Backups in `.finance-meta/backups/` (now pruned); repair log in
`.finance-meta/logs/`. No new store.
**Testing**: Swift Testing in macOS CI — App-target write view-model suites (WritePreview/Import/
Reassignment/RepairApply), multi-entry same-month + whole-group tests, `description`-dedup + absent-safe
read, backup-prune (retention + race-safety), the one-valid/one-invalid fixture matrix, and
read/write/repair integration; **XCUITest** module-view smoke (new); a **performance measurement**
harness (cold-launch, re-index) run manually + in CI where feasible; SwiftLint `--strict`.
Signing/notarization and two-device iCloud sync are **manual on real hardware** (CI builds unsigned).
**Target Platform**: macOS 15 (Sequoia)+ on Apple Silicon.
**Project Type**: Native macOS desktop app — SwiftPM package (`FinanceWorkspaceKit` +
`FinanceWorkspaceApp`) plus the XcodeGen app wrapper (`App/`) for signing.
**Performance Goals**: cold-launch-to-first-projection **≤ 2s**; full re-index of the 12-month fixture
**≤ 5s**; UI interactive (no perceptible stall) during re-index; repair-apply-plus-re-validate within
the ≤ 5s re-index bound.
**Constraints**: no schema change except the additive optional `description` column (NFR-001); every
mutation via the single `WriteService` safe-write path, primitives never reimplemented (NFR-002,
P-IV); multi-entry groups atomic in **one monthly file**; conflicts resolved by **explicit user
choice** over `NSFileVersion`, never auto-merged (P-IV); WCAG AA in light + dark; Developer ID signed +
notarized; no new product surface (NFR-003); all views clear `design-adherence`.
**Observability**: writes/repairs append to `repair-log.csv`; backup-prune actions are observable;
`WriteGate` reasons surface on disabled affordances; the conflict state surfaces per-file.
**Scale/Scope**: single user/workspace; 6 user stories; the one schema column; ~25 FRs + 3 NFRs.

No open `NEEDS CLARIFICATION` — the material ambiguities were resolved across the three 2026-07-06
clarify sessions; remaining plan-level choices are decided in `research.md` (D1–D12).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* — Source:
`.specify/memory/constitution.md` v1.1.1.

| Principle / Section | Gate | Status |
|---|---|---|
| I. Plain Files First | No hidden primary DB; every writable entity has a file representation | ✅ PASS — only an **additive optional** column; no new store; `ProjectionStore` stays non-authoritative and rebuilds from files |
| II. Read Model Second | Projections regenerable; per-file resilience; provenance distinguished | ✅ PASS — FR-016/017 *are* this principle: last-known-valid projection served during re-index, sparse-data resilience, provenance labels unchanged |
| III. Native Over Generic | macOS conventions; full keyboard nav; collapsible right pane | ✅ PASS — FR-018/020/021 harden keyboard nav, `NSUserActivity` restoration, the full menu set, and `.csv`/`.md` drag-drop; no cross-platform abstraction |
| IV. Safe Writes Only | Backup + preview + atomic + sync-gated + logged; conflicts by explicit choice | ✅ PASS — multi-entry atomic in one file; backup **retention/prune** added without weakening the guarantee; FR-012 pick-a-version = the P-IV "keep mine/keep iCloud/keep both" mandate over `NSFileVersion` |
| V. Traceability Always | KPI → detail → source; paths/timestamps visible | ✅ PASS — exports keep `source_file`/`source_row`; the new `description` is a traceable field; inspector unchanged |
| VI. Cross-Domain Visibility | Shared registry; links maintained | ✅ PASS — the reassignment picker keeps FKs valid on delete; registry/links unchanged |
| VII. Repair When Safe | Deterministic, previewable, confirmed, classified, logged | ✅ PASS — US6 adds **tests** for the existing repair flows; no change to classification or the confirm-after-diff contract |
| File & Schema Conventions | schema_version comment rows; unified ledger; `.finance-meta/` app-managed; migrations for breaking changes | ✅ PASS — adding an optional column is **explicitly not breaking** → no `schema_version` bump, no migration; the registry gains the optional `description`; backups stay in app-managed `.finance-meta/backups/` |
| V1 Scope Boundaries | No deferred-scope features; single workspace/user; tax = estimates | ✅ PASS — **require-iCloud** onboarding keeps the local-folder provider dev-only (no multi-workspace / alt-provider); no bank sync, no new modules; import/export stay file operations |

**Result: PASS.** No violations. Complexity Tracking is empty.

**Post-design re-check (after Phase 1 artifacts)**: PASS — the design adds no new persistent store and
no parallel write path. The one data change is an additive optional column (constitution-sanctioned as
non-breaking). Signing, performance, accessibility, and test work harden existing layers rather than
introducing abstractions. No Complexity Tracking entries.

## Project Structure

### Documentation (this feature)

```text
specs/008-polish-launch/
├── plan.md              # This file
├── research.md          # Phase 0 — D1 multi-entry editor, D2 reassignment picker, D3 budget-MD
│                        #   export, D4 typed forms, D5 description column + dedup, D6 App write tests,
│                        #   D7 signing/notarization, D8 iCloud sync + conflict UI, D9 performance,
│                        #   D10 reliability, D11 accessibility/native, D12 backup retention/prune +
│                        #   onboarding + fixture/XCUITest harness
├── data-model.md        # Phase 1 — the one schema touch + the config/behavior entities (perf budget,
│                        #   retention policy, conflict, signed artifact); reused write entities
├── quickstart.md        # Phase 1 — exercise each story against a temp fixture + the manual signed/
│                        #   two-device + perf/a11y checks
├── contracts/
│   ├── write-flow-completion.md   # multi-entry editor / reassignment picker / budget-MD / typed
│   │                              #   forms / description column ⇄ engine contracts (US2)
│   ├── packaging-and-sync.md      # signing + notarization + NSFileVersion conflict resolution (US3)
│   ├── performance-reliability.md # perf budget, projection caching, debounce, last-known-valid (US4)
│   ├── accessibility-native.md    # VoiceOver/WCAG AA, keyboard nav, NSUserActivity, drag-drop, menu (US5)
│   └── test-harness.md            # fixture matrix, integration + XCUITest, backup-prune (US6)
├── checklists/requirements.md     # /speckit-specify output (validated)
└── tasks.md             # /speckit-tasks output (NOT created here)
```

### Source Code (repository root)

Phase 7 adds the **bold** paths; everything else is consumed unchanged (US1 paths already edited this
session).

```text
Sources/
  FinanceWorkspaceKit/
    Platform/                        # consumed: BackupService, FileCoordinatorService, WriteGate,
                                     #   ManifestStore, ICloudContainerService (NSFileVersion conflicts)
    Parsing/
      Resources/Schemas/transactions.schema.json  # ← edited: + optional `description` column (US2/D5)
      CSVSchemaRegistry.swift / CSVNormalizer.swift # ← consumed/edited: register the optional column
    Persistence/Write/               # consumed: WriteService/WritePlan/MultiEntry/ReferenceScanner/
                                     #   ImportMapper (dedup key +description)/ExportService (budget MD)
      BackupPruneService.swift       # ← NEW: retention policy (last 10 + 30d), prune after write + launch (US6/D12)
  FinanceWorkspaceApp/
    AppState.swift / AppState+WriteFlows.swift  # ← edited: prune hook, projection cache, group/reassign state
    UI/
      Write/
        TransactionGroupEditor.swift  # ← NEW: multi-entry add/edit/delete (one file, whole-group) (US2/D1)
        ReassignmentPickerView.swift  # ← NEW: per-collection reassignment on delete (US2/D2)
        EntityEditForms.swift         # ← edited: typed controls (pickers, sign-aware amounts) (US2/D4)
      Budget/BudgetOverviewView.swift # ← edited: Markdown-summary export button (US2/D3)
      Shared/LedgerTableView.swift    # ← edited: whole-group edit/delete affordance (US2/D1)
      Onboarding/                     # ← NEW: require-iCloud first-launch flow (US5/D12)
      Shell/ (Conflict surface)       # ← NEW/edited: pick-a-version conflict resolution (US3/D8)
  App/                               # ← edited: project.yml signing/notarization config (US3/D7)
Tests/
  FinanceWorkspaceKitTests/          # ← + BackupPruneTests, description-dedup/absent-safe, fixture matrix
  FinanceWorkspaceAppTests/          # ← + WritePreview/Import/Reassignment VM + RepairApply integration
  FinanceWorkspaceUITests/           # ← NEW: XCUITest module-view smoke (US6)
Scripts / CLIs                       # ← + backup-prune (CLI equivalent), perf measurement harness
docs/out-of-scope-followups.md       # ← updated on completion (OOS-13…18 closed / re-triaged)
docs/test-plans.md                   # ← updated on completion (write-flow + launch flows testable)
```

**Structure Decision**: keep the Phase-6 split — mutation logic stays in
`FinanceWorkspaceKit/Persistence/Write/` (pure, `swift test`-able in CI on the CLT-only box; the new
`BackupPruneService` joins it), and the App target holds only SwiftUI (the two new write views, the
typed-form controls, the onboarding + conflict surfaces). Signing config lives in the existing
XcodeGen `App/` wrapper. XCUITest is a new App-side test target exercised on a Mac runner. This adds
no new abstraction between engines and files — the one data change is an additive optional column.

## Complexity Tracking

> No constitution violations — table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
