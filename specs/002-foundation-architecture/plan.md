# Implementation Plan: Foundation & Architecture (Phase 1)

**Branch**: `002-foundation-architecture` | **Date**: 2026-06-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/002-foundation-architecture/spec.md`

## Summary

Build the foundation layer of the FinanceWorkspaceApp: a storage-provider abstraction (iCloud ubiquity container + a DEBUG local-folder provider), first-launch workspace provisioning from canonical JSON schemas, a file index backed by a device-local regenerable manifest, detection of the seven iCloud sync states, the safe-write/conflict primitives (coordinated access, sync-state gating, manual conflict resolution, timestamped backups), and the typed canonical data model. Nothing ships as a finished user module — this is the floor every later phase derives its read model from.

Technical approach: native macOS SwiftUI app (Swift 6, Observation). Files remain canonical (no database); the manifest is a disposable cache rebuilt from scan. iCloud sync state and file watching come from `NSMetadataQuery`; local watching from FSEvents; safe access from `NSFileCoordinator` with `NSFileVersion` for manual conflict resolution; content hashing from CryptoKit SHA-256. JSON schemas in `.finance-meta/schemas/` drive bootstrap templates, classification, and (Phase 2) validation.

## Technical Context

**Language/Version**: Swift 6  
**Primary Dependencies**: SwiftUI, Observation; Foundation (`FileManager`, `NSFileCoordinator`, `NSFilePresenter`, `NSMetadataQuery`, `NSFileVersion`); CoreServices / FSEvents (local-folder watching); CryptoKit (SHA-256); UniformTypeIdentifiers  
**Storage**: Plain CSV + Markdown files in an app-owned iCloud ubiquity container (`iCloud.<bundle-id>`) — canonical source of truth. Device-local JSON manifest cache in `~/Library/Application Support/OpenFinance/<workspace_id>/`. No database.  
**Testing**: XCTest / Swift Testing; fixture-driven integration tests against a local-folder workspace (`~/Finance-Dev/`); SwiftLint on a GitHub Actions Linux runner  
**Target Platform**: macOS 15 (Sequoia) or newer  
**Project Type**: Native macOS desktop app — single Xcode project (`FinanceWorkspaceApp`)  
**Performance Goals**: cold-launch scan + hash of a realistic 12-month workspace within a few seconds on Apple Silicon (M1+); incremental single-file re-index without full rescan  
**Constraints**: offline-capable; plain files canonical (no hidden DB); read model always regenerable; writes are backed up, atomic, sync-gated, and never silently auto-merged  
**Scale/Scope**: single user, single workspace; ~24 canonical entity models; one schema per managed file type; 12+ monthly transaction files

No open `NEEDS CLARIFICATION` — all foundational decisions are locked in `docs/technical-design.md §21` and `docs/architecture/`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* — Source: `.specify/memory/constitution.md` v1.1.0.

| Principle / Section | Gate | Status |
|---|---|---|
| I. Plain Files First | No hidden primary DB; CSV/MD canonical; manifest is a non-authoritative cache | ✅ PASS — manifest is device-local regenerable cache (FR-011); files canonical |
| II. Read Model Second | Every derived value regenerable from files; reinstall reproduces projections | ✅ PASS — index rebuilds identically from scan (FR-011, SC-004) |
| III. Native Over Generic | macOS-native; `NavigationSplitView`; Finder-openable files | ✅ PASS (no UI built in Phase 1; files are Finder-compatible by construction) |
| IV. Safe Writes Only | Backup, atomic, sync-gated, manual conflict resolution, repair log | ✅ PASS — FR-013/014/015/016 cover the full write-safety primitive set |
| V. Traceability Always | KPI→source links | ➖ N/A — no projections/UI in Phase 1; deferred to later phases |
| VI. Cross-Domain Visibility | `Accounts/accounts.csv` master registry; `account_id` resolves | ✅ PASS — Account is the single master entity (FR-018); referenced by all transaction files |
| VII. Repair When Safe | Deterministic, previewable, classified repairs | ➖ PARTIAL/N/A — ValidationIssue/RepairAction contract stubbed (FR-017); full repair is Phase 2 |
| File & Schema Conventions | `# schema_version` comment row; unified ledger; three-tier classification; device-local manifest | ✅ PASS — FR-003 (comment-row marker), FR-007 (classification), FR-011 (manifest) |
| V1 Scope Boundaries | App-owned iCloud single workspace; no deferred-scope features | ✅ PASS — single workspace; no Notes/Issues/Files/sync/AI in scope |

**Result: PASS.** No violations. Complexity Tracking is empty.

**Post-design re-check (after Phase 1 artifacts)**: PASS — the data model (single `Account` struct, device-local `Manifest`, unified `Transaction` ledger), the `CloudStorageProvider` contract, and the workspace-layout contract introduce no new abstractions or deferred-scope features and remain consistent with constitution v1.1.0. No new entries in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/002-foundation-architecture/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── cloud-storage-provider.md
│   ├── manifest.schema.json
│   ├── workspace-layout.md
│   └── cli-scripts.md
├── checklists/
│   └── requirements.md  # from /speckit-specify
└── tasks.md             # /speckit-tasks output (NOT created here)
```

### Source Code (repository root)

The Xcode project follows the locked module layout (`docs/architecture/core-domain.md §2`). Phase 1 touches the **bold** folders; the rest are scaffolded empty for later phases.

```text
FinanceWorkspaceApp/
  App/                     # FinanceWorkspaceApp.swift, AppState, AppRouter (minimal shell)
  Platform/                # ← Phase 1 core
    WorkspaceManager.swift
    CloudStorageProvider.swift        (protocol)
    ICloudContainerService.swift      (v1 provider; NSMetadataQuery sync state)
    LocalFolderProvider.swift         (DEBUG default; FSEvents)
    FileIndexService.swift
    FileWatcherService.swift
    BackupService.swift
    FileCoordinatorService.swift
  Parsing/                 # (scaffold only — Phase 2)
  Domain/                  # ← Phase 1: model types only (no engines)
    Accounts/ Budget/ Savings/ Investments/ Taxes/ CrossDomain/  (*Models.swift)
  Validation/              # ← Phase 1: ValidationIssue, RepairAction model stubs
  Persistence/             # ← Phase 1: ManifestStore.swift
    ManifestStore.swift
  UI/Shared/               # (scaffold only)
  Scripts/                 # ← Phase 1
    bootstrap-workspace.swift
    fixture-generate.swift
FinanceWorkspaceAppTests/  # ← Phase 1 unit + fixture integration tests
.github/workflows/         # ← Phase 0: SwiftLint on Linux
.swiftlint.yml             # ← Phase 0
```

**Structure Decision**: Single native-macOS Xcode project (`FinanceWorkspaceApp`) with the locked five-layer module folders. Phase 1 implements the Platform layer, the data-model types across `Domain/`/`Validation/`, `Persistence/ManifestStore`, and the `Scripts/` bootstrap + fixture generators, with a sibling unit/integration test target. No web/mobile split.

## Complexity Tracking

> No Constitution Check violations — section intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
