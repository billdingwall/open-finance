---
description: "Task list for Foundation & Architecture (Phase 1)"
---

# Tasks: Foundation & Architecture (Phase 1)

**Input**: Design documents from `specs/002-foundation-architecture/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included — the spec is verification-heavy (8 success criteria, per-story Independent Tests, quickstart scenarios). Test tasks map to acceptance criteria; they are not strict TDD-first but should be written alongside their story.

**Organization**: Tasks are grouped by user story. Note this is a *foundation* feature: the stories form a natural build chain (provider → provisioning → index → sync), so they are sequenced by dependency, but each remains independently testable at its checkpoint.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1–US4 maps to the spec's user stories
- Paths are relative to repo root. App code lives under `FinanceWorkspaceApp/`; tests under `FinanceWorkspaceAppTests/`.

> **Implementation note (2026-06-28):** scaffolded as a **Swift Package** (`Package.swift`) rather than a hand-authored `.xcodeproj` — the environment has Swift 6.3 + Command Line Tools but no Xcode GUI / `xcodegen`, so SwiftPM is the buildable, CI-friendly choice. Architecture folders map to `Sources/FinanceWorkspaceKit/{Platform,Domain,Validation,...}`; the app is the `FinanceWorkspaceApp` executable; scripts are `bootstrap-workspace` / `fixture-generate` executables; tests use **Swift Testing** (`import Testing`). An Xcode app target + entitlements (T004) is deferred to when UI/packaging/iCloud signing is needed (the iCloud provider lands in US3). `swift build` passes; `swift test` runs in CI (XCTest/Testing are absent from the local CLT-only toolchain).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and structure (the Phase 0 toolchain layer).

- [X] T001 Create the `FinanceWorkspaceApp` Xcode project (macOS, SwiftUI lifecycle, Swift 6, deployment target macOS 15)
- [X] T002 Establish the module folder structure (`App/`, `Platform/`, `Parsing/`, `Domain/{Accounts,Budget,Savings,Investments,Taxes,CrossDomain}/`, `Validation/`, `Persistence/`, `UI/Shared/`, `Scripts/`) and the `FinanceWorkspaceAppTests/` target
- [X] T003 [P] Add `.swiftlint.yml` and `.github/workflows/swiftlint.yml` (SwiftLint on a Linux runner)
- [ ] T004 [P] Configure the iCloud ubiquity-container entitlement (`iCloud.<bundle-id>`) and capabilities (developer-machine only)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared models, the provider abstraction + local provider, file-safety primitives, schemas, and the minimal app shell that ALL user stories depend on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T005 [P] Define platform models (`Workspace`, `FileRecord`, `SyncStatus`, `Manifest`) in `FinanceWorkspaceApp/Platform/PlatformModels.swift`
- [X] T006 [P] Define validation model stubs (`ValidationIssue`, `RepairAction`) in `FinanceWorkspaceApp/Validation/ValidationModels.swift`
- [X] T007 [P] Define Accounts models (`Account` + nested `InvestmentMetadata?`, `AccountGroup`, `Liability`, `AccountRule`, `AccountEstimate`) in `FinanceWorkspaceApp/Domain/Accounts/AccountModels.swift`
- [X] T008 [P] Define `UnifiedTransaction` (multi-entry `group_id`/`group_role`, `sending_asset_id`/`receiving_asset_id`/`liability_id`, `type`) in `FinanceWorkspaceApp/Domain/Accounts/TransactionModels.swift`
- [X] T009 [P] Define Budget models (`Category`, `Budget`, `BudgetAllocation`) in `FinanceWorkspaceApp/Domain/Budget/BudgetModels.swift`
- [X] T010 [P] Define Savings models (`SavingsGoal` with `status` active|archived, `SavingsProgress`) in `FinanceWorkspaceApp/Domain/Savings/SavingsModels.swift`
- [X] T011 [P] Define Investments models (`Asset`, `Trade`, `PricePoint`, `BenchmarkPeriod`, `Portfolio`, `PortfolioSleeve`, `SleeveTarget`) in `FinanceWorkspaceApp/Domain/Investments/InvestmentModels.swift`
- [X] T012 [P] Define Taxes models (`TaxAdjustment`, `TaxEstimate`, `TaxDocument`, `EstimatedPayment`, `TaxArchiveYear`) in `FinanceWorkspaceApp/Domain/Taxes/TaxModels.swift`
- [X] T013 [P] Define `NoteDocument` + cross-domain projections (`AccountSummaryCard`, `OverviewSummaryCard`, `MonthlySnapshot`, `GoalFundingLink`, `SleeveFundingLink`, `TaxPrepSummary`, `TaxDeductionSummary`, `BusinessMonthlySummary`) in `FinanceWorkspaceApp/Domain/CrossDomain/CrossDomainModels.swift`
- [X] T014 Define the `CloudStorageProvider` protocol + `SyncState`/`FileSyncState` enums in `FinanceWorkspaceApp/Platform/CloudStorageProvider.swift` (per `contracts/cloud-storage-provider.md`)
- [X] T015 Implement `LocalFolderProvider` (DEBUG default, rooted at `~/Finance-Dev/`) conforming to `CloudStorageProvider` in `FinanceWorkspaceApp/Platform/LocalFolderProvider.swift` (depends on T014)
- [X] T016 [P] Author the canonical JSON schemas (one per managed file type) in the workspace template `.finance-meta/schemas/` per `contracts/workspace-layout.md`
- [X] T017 [P] Implement `FileCoordinatorService` (`NSFileCoordinator` wrapper) in `FinanceWorkspaceApp/Platform/FileCoordinatorService.swift`
- [X] T018 [P] Implement `BackupService` (timestamped copies → `.finance-meta/backups/`) in `FinanceWorkspaceApp/Platform/BackupService.swift`
- [X] T019 [P] Implement `Scripts/fixture-generate.swift` (≥12-month dataset → `~/Finance-Dev/`) per `contracts/cli-scripts.md`
- [X] T020 Implement the minimal app shell + active-provider selection (window + `AppState` surfacing workspace/sync state; **DEBUG defaults to `LocalFolderProvider`**, Release wires `ICloudContainerService` once it lands in US3; `os.Logger` diagnostics setup) in `FinanceWorkspaceApp/App/` (FR-021, FR-024, FR-025). Wiring the DEBUG default here keeps US1–US3 runnable without iCloud.

**Checkpoint**: Models compile; the local provider resolves a workspace; primitives and schemas exist — story work can begin.

---

## Phase 3: User Story 1 — First-launch workspace provisioning (Priority: P1) 🎯 MVP

**Goal**: On first launch the app resolves/creates the Finance workspace, lays down the standard tree, and seeds a valid starter workspace.

**Independent Test**: Launch against an empty location → full tree + six seed accounts + default categories + `Workspace.md` + manifest exist; re-launch preserves files (idempotent).

- [X] T021 [P] [US1] Integration test: first-launch provisioning yields the full tree + 6 seed accounts + categories + `Workspace.md` + manifest (SC-001) in `FinanceWorkspaceAppTests/ProvisioningTests.swift`
- [X] T022 [P] [US1] Integration test: idempotent bootstrap preserves existing files (SC-008) in `FinanceWorkspaceAppTests/ProvisioningTests.swift`
- [X] T023 [US1] Implement `WorkspaceManager` (resolve via active `CloudStorageProvider`, create initial tree, validate minimum required paths, restore last workspace from `UserDefaults`, expose observable `WorkspaceState`) in `FinanceWorkspaceApp/Platform/WorkspaceManager.swift`
- [X] T024 [US1] Implement `Scripts/bootstrap-workspace.swift`: create the folder tree, seed templates from the JSON schemas (each with a leading `# schema_version: 1`), seed six starter accounts + default categories + the standard tax-adjustment row + `Workspace.md`, per `contracts/workspace-layout.md`
- [X] T025 [US1] Implement idempotent provisioning and missing-required-path reporting (distinct from "unavailable") in `WorkspaceManager` (FR-004, FR-005)
- [X] T026 [US1] Surface provisioning/availability state in the app shell (FR-024)

**Checkpoint**: A valid, scannable workspace is produced on first run — this is the MVP.

---

## Phase 4: User Story 2 — Accurate, self-healing file index (Priority: P2)

**Goal**: Maintain a correct, incremental, regenerable index of the finance tree; `.finance-meta/` excluded; resilient to per-file failures.

**Independent Test**: Index a populated workspace; delete the manifest → identical rebuild; edit one file → only that file re-indexes; drop an unreadable file → it's flagged and the scan continues.

- [X] T027 [P] [US2] Integration test: scan classifies/hashes the finance tree + `Workspace.md` and excludes `.finance-meta/` (FR-007) in `FinanceWorkspaceAppTests/IndexScopeTests.swift`
- [X] T028 [P] [US2] Integration test: manifest delete → byte-identical rebuild from scan (SC-004); single external edit → incremental re-index only (SC-003) in `FinanceWorkspaceAppTests/IndexRebuildTests.swift`
- [X] T029 [P] [US2] Integration test: unreadable/locked file → `error` status + `os.Logger` entry + scan continues over all others (FR-011a) in `FinanceWorkspaceAppTests/IndexResilienceTests.swift`
- [X] T030 [US2] Implement `ManifestStore` (read/write the device-local Application Support manifest per `contracts/manifest.schema.json`; rebuild-from-scan when missing/corrupt) in `FinanceWorkspaceApp/Persistence/ManifestStore.swift`
- [X] T031 [US2] Implement `FileIndexService` (recursive discovery scoped to the finance tree + `Workspace.md`, excluding `.finance-meta/`; three-tier classification; SHA-256 hashing; per-file resilient error handling FR-011a; emit `FileChangeEvent`) in `FinanceWorkspaceApp/Platform/FileIndexService.swift`
- [X] T032 [US2] Implement incremental change detection (hash + modified-date vs prior manifest) and delta events in `FileIndexService`
- [X] T033 [US2] Implement the `FileWatcherService` FSEvents path (local-folder provider) with debounce + incremental re-index in `FinanceWorkspaceApp/Platform/FileWatcherService.swift`
- [X] T034 [US2] Wire `os.Logger` diagnostics for indexing failures (FR-025) in `FileIndexService`

**Checkpoint**: The index is correct, incremental, regenerable, and resilient.

---

## Phase 5: User Story 3 — Sync-state awareness & safe conflict handling (Priority: P3)

**Goal**: Detect the seven iCloud sync states, gate writes during sync, and resolve conflicts manually without data loss.

**Independent Test**: Drive each of the seven states and confirm detection/reporting + write gating; force a two-device conflict and resolve via keep mine/iCloud/both with no version lost.

- [ ] T035 [P] [US3] Controlled test: each of the 7 sync states is detected/reported; no write occurs while a file is mid-sync (SC-005) in `FinanceWorkspaceAppTests/SyncStateTests.swift`
- [ ] T036 [P] [US3] Integration test: simulated conflict resolvable via keep mine/iCloud/both, neither version lost (SC-006) in `FinanceWorkspaceAppTests/ConflictResolutionTests.swift`
- [ ] T037 [US3] Implement `ICloudContainerService` (resolve ubiquity container `iCloud.<bundle-id>`, availability state, per-file sync state from `NSMetadataQuery`) conforming to `CloudStorageProvider` in `FinanceWorkspaceApp/Platform/ICloudContainerService.swift`
- [ ] T038 [US3] Implement the 7-state detection + workspace/file `SyncStatus` mapping from `NSMetadataQuery` attributes
- [ ] T039 [US3] Extend `FileWatcherService` with the `NSMetadataQuery` watcher for the iCloud provider in `FinanceWorkspaceApp/Platform/FileWatcherService.swift`
- [ ] T040 [US3] Implement the sync-state write gate (block writes to syncing/downloading files; defer and surface inline) (FR-013, FR-015)
- [ ] T041 [US3] Implement manual conflict resolution via `NSFileVersion.unresolvedConflictVersions` (keep mine/iCloud/both) (FR-014)
- [ ] T042 [US3] Surface the sync states + conflict prompt in the app shell (FR-012, FR-024)

**Checkpoint**: Multi-device data integrity is protected before any write flow ships.

---

## Phase 6: User Story 4 — Reliable, iCloud-free development environment (Priority: P4)

**Goal**: Confirm the full provisioning + indexing path runs in DEBUG against the local folder with no iCloud, fixtures generate a realistic dataset, and CI is green.

**Independent Test**: DEBUG build resolves `~/Finance-Dev`, provisions + indexes a fixture workspace end-to-end; CI lint passes; the dual-mode resolution smoke test passes.

- [ ] T043 [US4] Verify the DEBUG build (provider selection wired in T020) resolves, provisions, and indexes `~/Finance-Dev` end-to-end with no iCloud configured (FR-021)
- [ ] T044 [P] [US4] Dual-mode workspace-resolution smoke test (iCloud + local-folder) in `FinanceWorkspaceAppTests/WorkspaceResolutionSmokeTests.swift` (FR-023)
- [ ] T045 [US4] Confirm CI runs SwiftLint to green on the Linux runner and the fixture → provision → index path runs end-to-end in DEBUG (SC-007)

**Checkpoint**: The development loop is solid and CI-enforced.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T046 [P] Run the `quickstart.md` verification table end-to-end in both modes
- [ ] T047 [P] Unit tests for hashing, classification, manifest round-trip, and sync-state mapping in `FinanceWorkspaceAppTests/Unit/`
- [ ] T048 Responsive cold-launch indexing sanity check on the fixture workspace (SC-002 soft target; hard thresholds deferred to Phase 7 of the roadmap)
- [ ] T049 [P] Update `CLAUDE.md` with build/test commands now that the Xcode project exists
- [ ] T050 Confirm the Milestone 1 gate: launch → resolve workspace (both modes) → provision on first run → scan + hash → persist manifest → detect/expose the 7 sync states → bootstrap produces a valid scannable workspace

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (P1)** → **Foundational (P2)** → user stories. Foundational blocks everything.
- **Story build chain** (foundation reality — not fully independent): **US1** (provisioning) needs the provider + `WorkspaceManager`; **US2** (index) consumes a provisioned/fixture workspace; **US3** (sync) layers the iCloud provider + sync state onto the index/provider; **US4** (dev env) verifies the whole loop. Build order: US1 → US2 → US3 → US4.
- **Polish (P7)** depends on the desired stories being complete.

### Independence note

Each story is independently **testable** at its checkpoint (US1: provisioning; US2: indexing on a provisioned/fixture workspace; US3: sync states via the iCloud provider; US4: DEBUG dev loop). They are not independently **deliverable** in arbitrary order because the platform substrate is shared — expected for a foundation phase.

### Parallel opportunities

- All Setup `[P]` tasks (T003, T004).
- All Foundational model tasks `[P]` (T005–T013) — different files, no interdependencies.
- Foundational primitives `[P]` (T016–T019) once T014/T015 exist.
- Within each story, the `[P]` test tasks run in parallel.

---

## Parallel Example: Foundational models

```bash
# Launch all domain-model tasks together (different files):
Task: "T007 Accounts models in Domain/Accounts/AccountModels.swift"
Task: "T009 Budget models in Domain/Budget/BudgetModels.swift"
Task: "T010 Savings models in Domain/Savings/SavingsModels.swift"
Task: "T011 Investments models in Domain/Investments/InvestmentModels.swift"
Task: "T012 Taxes models in Domain/Taxes/TaxModels.swift"
Task: "T013 NoteDocument + cross-domain projections in Domain/CrossDomain/CrossDomainModels.swift"
```

---

## Implementation Strategy

### MVP first (US1)

1. Phase 1 Setup → 2. Phase 2 Foundational → 3. Phase 3 US1 → **STOP & VALIDATE**: a first launch produces a complete, valid workspace (SC-001/SC-008). This is the demoable MVP floor.

### Incremental delivery

US1 (workspace exists) → US2 (it's indexed and self-healing) → US3 (it's sync-safe) → US4 (the dev loop is solid and CI-enforced) → Polish (quickstart + Milestone 1 gate).

---

## Notes

- `[P]` = different files, no dependencies; `[Story]` = traceability to spec user stories.
- `FileWatcherService` is implemented incrementally: FSEvents (US2, T033) then `NSMetadataQuery` (US3, T039).
- Tests map to the spec's Success Criteria (SC-001…SC-008) and clarified behaviors (FR-011a, FR-007 exclusion, FR-025).
- Commit after each task or logical group; stop at any checkpoint to validate a story.
- Milestone 1 (T050) is the Phase 1 exit gate.
