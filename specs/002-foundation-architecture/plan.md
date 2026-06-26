# Implementation Plan: Foundation & Architecture (Phase 1)

**Branch**: `002-foundation-architecture` | **Date**: 2026-06-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/002-foundation-architecture/spec.md`

> Re-run 2026-06-26 to fold in the `/speckit-clarify` Session 2026-06-26 answers (resilient per-file indexing, `.finance-meta/` exclusion, `os.Logger` diagnostics).

## Summary

Build the foundation layer of the FinanceWorkspaceApp: a storage-provider abstraction (iCloud ubiquity container + a DEBUG local-folder provider), first-launch workspace provisioning from canonical JSON schemas, a **resilient** file index backed by a device-local regenerable manifest, detection of the seven iCloud sync states, the safe-write/conflict primitives (coordinated access, sync-state gating, manual conflict resolution, timestamped backups), and the typed canonical data model. Nothing ships as a finished user module — this is the floor every later phase derives its read model from.

Technical approach: native macOS SwiftUI app (Swift 6, Observation). Files remain canonical (no database); the manifest is a disposable cache rebuilt from scan. iCloud sync state and file watching come from `NSMetadataQuery`; local watching from FSEvents; safe access from `NSFileCoordinator` with `NSFileVersion` for manual conflict resolution; content hashing from CryptoKit SHA-256. JSON schemas in `.finance-meta/schemas/` drive bootstrap templates, classification, and (Phase 2) validation. Indexing is **resilient per-file** (one unreadable file is recorded with an `error` status and skipped, never aborting the scan) and **scoped to the finance content tree** — the app-managed `.finance-meta/` subtree is excluded. Foundation failures are logged via `os.Logger` (workspace `logs/` stay reserved for user audit).

## Technical Context

**Language/Version**: Swift 6  
**Primary Dependencies**: SwiftUI, Observation; Foundation (`FileManager`, `NSFileCoordinator`, `NSFilePresenter`, `NSMetadataQuery`, `NSFileVersion`); CoreServices / FSEvents (local-folder watching); CryptoKit (SHA-256); `os.Logger` (unified logging); UniformTypeIdentifiers  
**Storage**: Plain CSV + Markdown files in an app-owned iCloud ubiquity container (`iCloud.<bundle-id>`) — canonical source of truth. Device-local JSON manifest cache in `~/Library/Application Support/OpenFinance/<workspace_id>/`. No database.  
**Testing**: XCTest / Swift Testing; fixture-driven integration tests against a local-folder workspace (`~/Finance-Dev/`); SwiftLint on a GitHub Actions Linux runner  
**Target Platform**: macOS 15 (Sequoia) or newer  
**Project Type**: Native macOS desktop app — single Xcode project (`FinanceWorkspaceApp`)  
**Performance Goals**: cold-launch scan + hash of a realistic 12-month workspace within a few seconds on Apple Silicon (M1+); incremental single-file re-index. Hard thresholds are set in Phase 7.  
**Constraints**: offline-capable; plain files canonical (no hidden DB); read model always regenerable; **resilient indexing** (one bad file never aborts a scan); writes backed up, atomic, sync-gated, never silently auto-merged  
**Observability**: foundation failures (resolution, indexing, sync) recorded to `os.Logger` and surfaced coarsely (available/error) in the app shell; workspace `.finance-meta/logs/` reserved for user audit  
**Scale/Scope**: single user, single workspace; ~25 canonical entity models; one schema per managed file type; 12+ monthly transaction files

No open `NEEDS CLARIFICATION` — foundational decisions locked in `docs/technical-design.md §21` / `docs/architecture/`; spec ambiguities resolved in the `/speckit-clarify` Session 2026-06-26.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* — Source: `.specify/memory/constitution.md` v1.1.0.

| Principle / Section | Gate | Status |
|---|---|---|
| I. Plain Files First | No hidden primary DB; CSV/MD canonical; manifest is a non-authoritative cache | ✅ PASS — device-local regenerable cache (FR-011) |
| II. Read Model Second | Regenerable from files; resilient to per-file failure | ✅ PASS — rebuild from scan (FR-011, SC-004); one bad file does not block others (FR-011a, satisfies "parsing failures … MUST NOT block … unrelated domains") |
| III. Native Over Generic | macOS-native; Finder-openable files | ✅ PASS — minimal shell only (FR-024); files Finder-compatible |
| IV. Safe Writes Only | Backup, atomic, sync-gated, manual conflict, repair log | ✅ PASS — FR-013/014/015/016 |
| V. Traceability Always | KPI→source links | ➖ N/A in Phase 1 (no projections/UI) |
| VI. Cross-Domain Visibility | `Accounts/accounts.csv` master registry; `account_id` resolves | ✅ PASS — single `Account` master (FR-018) |
| VII. Repair When Safe | Deterministic, previewable, classified repairs | ➖ PARTIAL/N/A — ValidationIssue/RepairAction contract stubbed (FR-017); full repair Phase 2 |
| File & Schema Conventions | `# schema_version` comment row; unified ledger; three-tier classification; device-local manifest; `.finance-meta/` app-managed | ✅ PASS — FR-003, FR-007 (incl. `.finance-meta/` exclusion), FR-011 |
| V1 Scope Boundaries | App-owned iCloud single workspace; no deferred-scope features | ✅ PASS |

**Result: PASS.** No violations. Complexity Tracking is empty.

**Post-design re-check (after Phase 1 artifacts + clarifications)**: PASS — resilient indexing (FR-011a) strengthens Principle II; `os.Logger` diagnostics (FR-025) add observability without new abstractions or deferred-scope features; `.finance-meta/` exclusion aligns with the File & Schema Conventions. No Complexity Tracking entries.

## Project Structure

### Documentation (this feature)

```text
specs/002-foundation-architecture/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   ├── cloud-storage-provider.md
│   ├── manifest.schema.json
│   ├── workspace-layout.md
│   └── cli-scripts.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks output (NOT created here)
```

### Source Code (repository root)

Phase 1 touches the **bold** folders; the rest are scaffolded for later phases (`docs/architecture/core-domain.md §2`).

```text
FinanceWorkspaceApp/
  App/                     # FinanceWorkspaceApp.swift, AppState, AppRouter (minimal shell — FR-024)
  Platform/                # ← Phase 1 core
    WorkspaceManager.swift
    CloudStorageProvider.swift        (protocol)
    ICloudContainerService.swift      (NSMetadataQuery sync state, NSFileVersion conflicts)
    LocalFolderProvider.swift         (DEBUG default; FSEvents)
    FileIndexService.swift            (resilient scan; .finance-meta/ excluded; os.Logger)
    FileWatcherService.swift
    BackupService.swift
    FileCoordinatorService.swift
  Parsing/                 # (scaffold only — Phase 2)
  Domain/                  # ← Phase 1: model types only (no engines)
    Accounts/ Budget/ Savings/ Investments/ Taxes/ CrossDomain/  (*Models.swift)
  Validation/              # ← Phase 1: ValidationIssue, RepairAction model stubs
  Persistence/             # ← Phase 1: ManifestStore.swift
  UI/Shared/               # ← Phase 1: minimal launch surface only
  Scripts/                 # ← Phase 1: bootstrap-workspace.swift, fixture-generate.swift
FinanceWorkspaceAppTests/  # ← Phase 1 unit + fixture integration tests
.github/workflows/         # ← Phase 0: SwiftLint on Linux
.swiftlint.yml             # ← Phase 0
```

**Structure Decision**: Single native-macOS Xcode project (`FinanceWorkspaceApp`) with the locked five-layer module folders. Phase 1 implements the Platform layer, the data-model types across `Domain/`/`Validation/`, `Persistence/ManifestStore`, a minimal app shell, and the `Scripts/` bootstrap + fixture generators, with a sibling unit/integration test target. No web/mobile split.

## Complexity Tracking

> No Constitution Check violations — section intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
