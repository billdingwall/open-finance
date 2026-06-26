---
round: 8
doc: technical-design.md
date: 2026-06-26
status: APPLIED 2026-06-26 to canonical docs
source: docs/_refinement/r8-review.md (dispositions confirmed by principal 2026-06-26)
---

# R8 Update Plan — technical-design.md

Section-by-section change list. Implements the confirmed R8 dispositions for the
dev-environment / data-storage / data-sync foundation.

## §5 Workspace and iCloud model

**Storage provider abstraction**
- Add: in **DEBUG builds the default `CloudStorageProvider` is a local-folder
  provider** rooted at `~/Finance-Dev/` (populated by `fixture-generate`). Live
  iCloud is exercised only in Release/TestFlight builds. Keeps the dev loop free of
  entitlement/signing round-trips and CI-runnable.

**Workspace resolution (container ID fix — `[DECIDE]` entitlement + correction)**
- Change the code block identifier from `"OpenFinance"` to the reverse-DNS
  `iCloud.`-prefixed form, e.g. `iCloud.com.<org>.OpenFinance`.
- Add a sentence: this exact string is what populates the
  `com.apple.developer.ubiquity-container-identifiers` entitlement array; the bare
  `OpenFinance` value resolves to `nil` at runtime.
- One container identifier across development and distribution (iCloud Documents has
  no dev/prod split). Dev-data isolation happens at the provider layer (above), not
  via a separate container.

**Sync considerations (`[DECIDE]` 7 sync states)**
- Add that per-file sync state is sourced from **`NSMetadataQuery`** (scope
  `NSMetadataQueryUbiquitousDocumentsScope`), not hand-tracked.
- Add the 7-state → UI-treatment table:

  | State | UI treatment | Writes |
  |---|---|---|
  | Available | No indicator (subtle green header sync chip) | Enabled |
  | Not signed into iCloud | Full-screen blocking onboarding + local-folder fallback | — |
  | Container unavailable | Full-screen blocking + diagnostics + retry | — |
  | Syncing (workspace) | Persistent header chip "Syncing…" | Disabled (sync-first write gate) |
  | Local copy stale | Per-file row indicator + dismissible banner | Gated per-file |
  | File missing locally (placeholder) | Per-file indicator + download affordance (`startDownloadingUbiquitousItem`) | Gated |
  | Conflict detected | Banner + per-file indicator → resolution surface | Gated |

**New subsection — Conflict resolution (v1)**
- v1 does **not** auto-merge. Surface `NSFileVersion.unresolvedConflictVersions` with
  a "Keep mine / Keep iCloud / Keep both" choice. Never silently merge finance files.

## §9 Metadata model

**schema_version attribute (`[DECIDE]` format)**
- Specify storage format: a **leading CSV comment row** `# schema_version: 1` as
  line 1 of every managed CSV. `CSVParserService` tolerates and strips leading `#`
  comment lines. If absent, assume the registry's current version and flag for
  repair. Note the accepted tradeoff (Numbers/Excel render it as a junk first row).

**App-managed manifest (`[DECIDE]` location + field set)**
- Change **Path** from `.finance-meta/manifest.json` to
  `~/Library/Application Support/OpenFinance/<workspace_id>/manifest.json`.
- Add rationale: the manifest is a **device-local, regenerable cache**, kept out of
  the synced container so it cannot conflict/stale across Macs. A missing/corrupt
  manifest triggers a rescan, never data loss. Constitution #1/#2 consistent.
- Update per-file fields to: `path, domain, subtype, schema_version, hash (sha256),
  modified_at, byte_size, row_count, last_indexed_at, validation_status (counts by
  severity)`. Top-level: `manifest_schema_version, app_version, workspace_id,
  last_indexed_at`.
- Explicitly exclude per-file **sync state** (volatile; OS/`NSMetadataQuery` owns it)
  and **repair history** (lives in `logs/repair-log.csv`).
- Note: `.finance-meta/` in iCloud now carries only `schemas/`, `backups/`, `logs/`.

## §21 Decisions to lock before build

- Add a new lock block **"Locked — 2026-06-26 (Round 8 — foundation hardening)"**:
  - Ubiquity container identifier format = `iCloud.<bundle-id>` (corrects the bare
    `OpenFinance` value recorded under the 2026-06-10 block — update that entry too).
  - DEBUG default provider = local folder `~/Finance-Dev/`.
  - Manifest = device-local cache in Application Support (fields above).
  - schema_version = leading `# schema_version:` comment row, tolerant parser.
  - File watching = `NSMetadataQuery` (iCloud) + FSEvents (local); `DispatchSource`
    and hand-rolled `NSFilePresenter`-as-watcher rejected. `NSFileCoordinator` is for
    read/write coordination only.
  - 7 sync-state UI treatments (table above) + conflict UX (manual, `NSFileVersion`).
  - `Account` model = single struct with optional nested `InvestmentMetadata?`; no
    `InvestmentAccount` subtype.
- Update **"Open decisions (pre-build)"** list: remove iCloud entitlement strategy,
  7 sync states, and manifest field set (now locked).

## §24 Changelog
- Add Round 8 entry summarizing the above.
