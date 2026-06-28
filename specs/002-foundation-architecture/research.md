# Phase 0 Research — Foundation & Architecture

All foundational unknowns were resolved during Rounds 6–8 and are locked in
`docs/technical-design.md §21` and `docs/architecture/`. This file consolidates the decisions
that drive the Phase 1 design. No open `NEEDS CLARIFICATION` remain.

## R1 — iCloud workspace resolution & entitlement

- **Decision**: App-owned ubiquity container with identifier `iCloud.<bundle-id>` (reverse-DNS,
  `iCloud.`-prefixed). Resolve via `FileManager.url(forUbiquityContainerIdentifier:)` → `Documents/Finance`.
  One identifier across dev and distribution.
- **Rationale**: Apple's ubiquity container pathing is predictable and is the native document-store
  model. The bare string `OpenFinance` resolves to `nil` at runtime (R8 correction).
- **Alternatives**: User-selected iCloud Drive folder (advanced mode) — deferred to V2; separate
  dev container — not a real distinction for iCloud Documents (no dev/prod split).

## R2 — Provider abstraction & dev loop

- **Decision**: `CloudStorageProvider` protocol (`resolveWorkspaceURL() async throws -> URL`,
  observable `syncState`, `isAvailable`). `ICloudContainerService` is the v1 implementation; a
  `LocalFolderProvider` rooted at `~/Finance-Dev/` is the **DEBUG default**.
- **Rationale**: Decouples the app from iCloud, makes workspace resolution CI-testable, and removes
  entitlement/signing friction from day-to-day development. Sets up V2 backends (Drive/Dropbox).
- **Alternatives**: Direct iCloud API calls throughout — rejected (untestable, no fallback).

## R3 — Sync state & file watching

- **Decision**: `NSMetadataQuery` (`NSMetadataQueryUbiquitousDocumentsScope`) is the primary watcher
  and source of per-file sync state for the iCloud provider; **FSEvents** for the local-folder
  provider. `NSFileCoordinator`/`NSFilePresenter` are used only for read/write coordination.
- **Rationale**: `NSMetadataQuery` directly yields `NSMetadataUbiquitousItemDownloadingStatusKey`,
  percent-downloaded, upload/download-in-progress, and conflict flags — i.e. it produces the seven
  sync states without hand-tracking. `DispatchSource` (single fd) doesn't scale to a tree and is
  blind to placeholder→materialized transitions; hand-rolled `NSFilePresenter`-as-watcher is brittle.
- **Alternatives**: `DispatchSource`, `NSFilePresenter`-as-watcher — both rejected (R8).

## R4 — Conflict resolution

- **Decision**: No auto-merge in v1. Surface `NSFileVersion.unresolvedConflictVersions` with a
  "Keep mine / Keep iCloud / Keep both" choice.
- **Rationale**: Finance files must never be silently merged; the OS version API is the supported,
  non-destructive path. (Constitution IV.)
- **Alternatives**: Last-writer-wins / automatic three-way merge — rejected (data-loss risk).

## R5 — Manifest location & shape

- **Decision**: Device-local, regenerable JSON cache at
  `~/Library/Application Support/OpenFinance/<workspace_id>/manifest.json` — **outside** the synced
  container. Per-file fields: `path, domain, subtype, schema_version, hash (sha256), modified_at,
  byte_size, row_count, last_indexed_at, validation_status`. Top level: `manifest_schema_version,
  app_version, workspace_id, last_indexed_at`. Sync state and repair history are excluded.
- **Rationale**: A synced manifest would conflict/stale across devices that index on independent
  schedules. As a pure cache it is rebuildable from scan, so loss is never data loss. The synced
  `.finance-meta/` then carries only `schemas/`, `backups/`, `logs/`.
- **Alternatives**: Manifest in `.finance-meta/` (synced) — rejected (cross-device conflicts).

## R6 — schema_version format

- **Decision**: Leading `# schema_version: N` comment row (line 1) on every managed CSV; parser
  strips leading `#` lines; absent ⇒ assume current registry version + flag for repair. Markdown
  declares it in front matter.
- **Rationale**: Files must be self-describing because the manifest is a disposable device-local
  cache. A per-row column wastes a cell on every row; manifest-only is too fragile. Accepted tradeoff:
  Numbers/Excel render the comment as a junk first row.
- **Alternatives**: dedicated column; manifest-only — both rejected (R8).

## R7 — Canonical schemas as source of truth

- **Decision**: Author one machine-readable JSON schema per managed file type in
  `.finance-meta/schemas/`. These drive bootstrap templates, the (Phase 2) `CSVSchemaRegistry`,
  validation, and migrations.
- **Rationale**: Single source of truth keeps bootstrap, registry, and validation in agreement and
  avoids prose drift. (Per-file enum enumeration is finalized in Phase 2.)
- **Alternatives**: Hardcoded Swift schemas — rejected (duplicates the spec, drifts).

## R8 — Content hashing & change detection

- **Decision**: SHA-256 (CryptoKit) over file bytes; compare hash + modified date to the prior
  manifest entry to classify add/change/delete; re-index only changed files; debounce watcher events.
- **Rationale**: Deterministic, cheap, and gives incremental re-index. Hash guards against
  modified-date-only false positives.
- **Alternatives**: Full rescan on any change — rejected (perf, SC-002/SC-003).

## R9 — State model & concurrency

- **Decision**: Observation (`@Observable`) for `WorkspaceState`/`SyncState`; async resolution;
  serialize file I/O through `FileCoordinatorService`.
- **Rationale**: Native, predictable updates; macOS 15 satisfies the Observation requirement.
- **Alternatives**: Combine / manual KVO — rejected (heavier, less idiomatic in Swift 6).

## R10 — Toolchain & CI

- **Decision**: macOS 15, Xcode 16, Swift 6; SwiftLint on a GitHub Actions Linux runner in Phase 1;
  full Mac build CI deferred to Phase 5; signing/entitlements developer-machine only until then.
- **Rationale**: Locked in R7. Linux lint keeps CI cheap while the local-folder provider makes the
  core logic runnable without a Mac runner.
- **Alternatives**: Mac CI runner now — deferred (cost; not needed until packaging).

## R11 — Resilient indexing (clarify Session 2026-06-26, Q1)

- **Decision**: A file that cannot be read or hashed during a scan is isolated, not fatal —
  `FileIndexService` records it in the manifest with an `error` status, logs it via `os.Logger`,
  and continues indexing every other file. One bad file never aborts the pass.
- **Rationale**: Directly satisfies Constitution Principle II ("parsing failures in one file MUST NOT
  block projections for unrelated domains") and keeps the index regenerable and trustworthy.
- **Alternatives**: Abort the whole scan on first failure (rejected — brittle); skip silently
  (rejected — hides corruption, untestable).

## R12 — Index scope excludes `.finance-meta/` (clarify Session 2026-06-26, Q2)

- **Decision**: The file index covers the finance content tree (`Accounts/`, `Budget/`, `Savings/`,
  `Investments/`, `Taxes/`, `Notes/`) plus the root `Workspace.md` (classified under the `meta`
  domain). The app-managed `.finance-meta/` subtree is excluded.
- **Rationale**: `.finance-meta/logs/*.csv` are written by the app; indexing them would create a
  re-index feedback loop and catalogue the app's own bookkeeping. Matches the constitution's
  treatment of `.finance-meta/` as non-source-of-truth support data.
- **Alternatives**: Index everything under a `meta` domain (rejected — feedback loop); partial
  exclusion with suppressed events (rejected — added complexity for no benefit).

## R13 — Foundation diagnostics via `os.Logger` (clarify Session 2026-06-26, Q3)

- **Decision**: Foundation-level failures (workspace resolution, indexing, sync) are recorded to the
  macOS unified log (`os.Logger`) and surfaced coarsely (available/error) in the app shell. Workspace
  `.finance-meta/logs/` files stay reserved for user-facing audit (`repair-log.csv`, `import-log.csv`).
- **Rationale**: Unified logging is the macOS-native diagnostic channel; keeps device-local
  diagnostics out of the synced workspace; avoids over-building a bespoke logging subsystem.
- **Alternatives**: A synced workspace diagnostic CSV (rejected — syncs noise across devices);
  defer all diagnostics (rejected — failures would be undiagnosable in Phase 1).
