---
round: 8
date: 2026-06-26
type: principal review / direction note
summary: Principal-engineer pass over the Phase 1–2 open decisions (project-management.md), focused on dev environment, data storage, and data syncing being solid before the build begins. Recommendations are proposed direction, not yet applied.
inputs:
  - docs/project-management.md (Phase 1 & 2 open items)
docs reviewed for prioritization:
  - docs/technical-design.md (§5 iCloud model, §9 metadata/manifest, §21 locked decisions)
  - docs/architecture/core-domain.md (§2–3 module layout, services)
  - docs/architecture/data-pipelines.md (read/write/index flows)
  - docs/product-roadmap.md (Phase 1 & 2 tasks)
status: APPLIED 2026-06-26 — all r8-update plans applied to canonical docs; 15 items retired
---

# Round 8 Review — Foundation Hardening (Phases 1–2)

## Purpose

A targeted engineering review of every open item in `docs/project-management.md`
for the early build phases, scoped to three concerns the principal flagged as the
things that must be solid before Phase 1 build starts:

1. **Development environment** — entitlements, signing, CI, local dev loop.
2. **Data storage** — manifest, schema versioning, schemas, core models.
3. **Data syncing** — file watching, the 7 iCloud sync states, conflicts.

This is **not** a prototype review. It is a foundation-hardening pass. Items below
are recommendations (proposed direction); each becomes a `[DECIDE]` resolution or a
`[FIX]` correction once the principal confirms. Nothing here is applied to the
canonical docs yet.

> **Framing note — there is no Phase 0.** Phase 1 currently bundles toolchain/
> environment bootstrap together with platform code. Several "is the dev
> environment solid?" concerns are really *prerequisites* to writing platform code.
> R8 recommends carving a lightweight **Phase 0 "Project & Environment Bootstrap"**
> out of the front of Phase 1 (see A2). No global renumber required if expressed as
> a Phase 1 sub-track.

---

## Section A — Development environment

### A1. iCloud entitlement strategy — `[DECIDE]` Phase 1 (+ correction)

**Bug found:** `docs/technical-design.md §5` states the container identifier is
`OpenFinance` and shows `url(forUbiquityContainerIdentifier: "OpenFinance")`. This
value is malformed. Ubiquity container identifiers must be reverse-DNS with an
`iCloud.` prefix (e.g. `iCloud.com.<org>.OpenFinance`), and that exact string is
what populates the `com.apple.developer.ubiquity-container-identifiers` entitlement
array. `"OpenFinance"` alone resolves to `nil` at runtime — the most common
iCloud-container setup failure. **Correct the identifier in §5, §21, and the
roadmap Phase 1 task before any entitlement is written.**

**Recommendation:**
- **One container identifier across dev and distribution.** iCloud *Documents*
  storage has no dev/prod split (that's a CloudKit-database feature, not a ubiquity
  container). Do not design for a "separate development container."
- **Isolate dev data at the provider layer, not the container layer.** In DEBUG
  builds, default the `CloudStorageProvider` to a **local-folder provider** pointing
  at `~/Finance-Dev/` (populated by the planned `fixture-generate` script). Day-to-day
  development then needs no entitlement round-trips, no signing, no live iCloud, and
  runs on CI. The iCloud path is exercised in Release/TestFlight builds.

*Resolves:* `[DECIDE]` iCloud entitlement strategy. *Also corrects:* §5/§21
identifier format.

### A2. Formalize a Phase 0 environment track — new structural recommendation

Bundle the following into an explicit pre-platform checklist (Phase 0 / Phase 1
setup sub-track): entitlement + local-dev signing, the DEBUG local-folder provider,
`fixture-generate`, SwiftLint + GitHub Actions (already locked), and a smoke test
that resolves a workspace URL in both iCloud and local-folder modes. This is the
concrete embodiment of the existing Phase 1 gate ("do not advance until the
workspace URL resolves reliably in both iCloud and local-fallback modes").

*Already locked, no reopening:* macOS 15 / Xcode 16 / Swift 6; GitHub Actions
SwiftLint on Linux in Phase 1; Mac build CI deferred to Phase 5. R8 only sequences
these into a checklist.

---

## Section B — Data storage

### B1. `manifest.json` field set — `[DECIDE]` Phase 1 (+ sync hazard)

**Hazard found:** the manifest currently lives at `.finance-meta/manifest.json`
*inside the iCloud container*, so the manifest itself syncs. Two Macs index on
independent schedules, so a synced manifest will conflict and go stale — a volatile
cache placed directly in the conflict-prone path.

**Recommendation:**
- **Move the manifest out of the synced workspace.** Treat it as a device-local,
  regenerable cache at `~/Library/Application Support/OpenFinance/<workspace_id>/
  manifest.json`. Fully consistent with Constitution #1/#2 (files canonical; read
  model regenerable). `.finance-meta/` in iCloud then carries only what *should*
  travel: `schemas/`, `backups/`, `logs/`.
- **Field set (pure index/cache):** `path`, `domain`, `subtype`, `schema_version`,
  `hash` (sha256), `modified_at`, `byte_size`, `row_count`, `last_indexed_at`,
  `validation_status` (counts by severity). Top level: `manifest_schema_version`,
  `app_version`, `workspace_id`, `last_indexed_at`.
- **Explicitly excluded:** per-file *sync state* (volatile; OS/`NSMetadataQuery` is
  the source of truth — see C2); *repair history* (belongs in
  `logs/repair-log.csv`). A missing/corrupt manifest is never data loss — it
  triggers a rescan.

*Resolves:* `[DECIDE]` manifest per-file field set. *Cascades:* §9 manifest path +
example; §6 `.finance-meta/` contents description.

### B2. `schema_version` header format — `[DECIDE]` Phase 2

**Recommendation: leading CSV comment row** (`# schema_version: 1` as line 1).
Files must be self-describing because the manifest is now a disposable device-local
cache (B1) — any machine must validate a file without it. A per-row column wastes a
cell on every row and clutters the grid; manifest-only is too fragile.

- **Accepted caveat:** Numbers/Excel render a `#` line as a junk first row.
  Mitigation: `CSVParserService` tolerates and strips leading `#` comment lines, and
  treats an absent version as "current registry version, flag for repair." Lesser
  evil than polluting every data row; keeps files Finder-compatible enough.

*Resolves:* `[DECIDE]` schema_version header format (Phase 2 dev + Phase 2 product
"one format, applied consistently").

### B3. CSV spec gaps — enum sets, required-vs-optional — `[DECIDE]` Phase 2

**Recommendation:** author the 28 file schemas as **machine-readable JSON in
`.finance-meta/schemas/`** (a path CLAUDE.md already reserves) *before* Swift. One
source of truth driving `CSVSchemaRegistry`, `ValidationEngine`, bootstrap
templates, and migrations. This also absorbs **`[FIX-S9]`** (account-group display
name ↔ enum mapping) — encode it in the schema, not scattered prose.

*Resolves:* `[DECIDE]` CSV spec gaps; `[FIX-S9]`. *Mechanically apply alongside:*
`[FIX R6-M1…M5]` schema renames/additions land in these JSON schemas.

### B4. `Account` model shape — `[DECIDE]` Phase 1

**Recommendation:** single `Account` struct with an optional nested
`InvestmentMetadata?` — **not** an `InvestmentAccount` subtype. A subtype fights the
locked unified-`accounts.csv` decision; `PortfolioEngine` filters
`account_group == .investment`. Effectively pre-decided by the locked registry;
recommend formally closing it.

*Resolves:* `[DECIDE]` Account model shape.

### B5. `OwnerDistribution` — `[FIX-S5]` Phase 1

**Recommendation: remove from v1.** Owner-draw/business-equity accounting with no
CSV spec; Business is now a `group_type`, not a module. Cut from PRD data model and
the Phase 1 entity list.

### B6. `savings-goal-contributions.csv` — `[FIX-S4]` Phase 2

**Recommendation: remove it.** The `savings_goal_id` column on transactions is
already the budget-to-goal linking mechanism. A separate contributions file
duplicates derivable data and will diverge. Confirm `savings_goal_id` as the sole
mechanism.

### B7. Savings-goal `status` enum — `[FIX-S7]` Phase 2 (+ contradiction)

**Contradiction found:** `core-domain.md §3` says "no goal lifecycle states in v1 —
every goal is active," but the roadmap (Phase 4/5) and S&I design assume
active/archived tabs.

**Recommendation:** minimal **`active | archived`** enum (drop `paused`/`completed`
— "completed" is derived from progress ≥ target). Reconcile the `core-domain.md`
note and `SavingsGoalEngine` description to acknowledge the single `archived`
lifecycle state.

### B8. Mechanical storage FIX items (no decision — apply)

`[FIX-M3]`, `[FIX-M6]`, `[FIX-C6]` (entity naming: `Transaction`, drop
`Personal/BusinessTransaction`, rename `BusinessEntity`); `[FIX R6-M1…M5]` (schema
renames/additions + `migrate-r6` script). These are doc/registry corrections — fold
into the B3 JSON-schema authoring and the §10 entity-list cleanup.

---

## Section C — Data syncing

### C1. `FileWatcherService` implementation — `[DECIDE]` Phase 1 (re-framed)

The doc poses `DispatchSource` vs `NSFilePresenter`. R8 rejects both as the
*primary* mechanism:
- `DispatchSource` (kqueue/vnode) watches one file descriptor — doesn't scale to a
  tree, blind to iCloud placeholder→materialized transitions.
- Hand-rolled `NSFilePresenter`-as-watcher is brittle.

**Recommendation:**
- **`NSMetadataQuery`** (scope `NSMetadataQueryUbiquitousDocumentsScope`) as the
  primary watcher for the iCloud provider. Purpose-built; hands you per-item
  `NSMetadataUbiquitousItemDownloadingStatusKey`, percent-downloaded,
  upload/download-in-progress, and conflict flags — i.e. it produces the 7 sync
  states directly (see C2).
- **FSEvents** (directory-tree, naturally coalescing) for the local-folder
  dev/V2 provider.
- Keep `NSFileCoordinator`/`NSFilePresenter` for read/write *coordination* only —
  not change detection.

This collapses C1 + C2 into one coherent mechanism.

*Resolves:* `[DECIDE]` FileWatcherService implementation. *Cascades:* roadmap Phase 1
`FileWatcherService` task wording; `core-domain.md §3` FileWatcherService /
ICloudContainerService.

### C2. The 7 sync-state UI treatments — `[DECIDE]` Phase 1 (+ Design)

Recommended mapping (each maps onto an `NSMetadataQuery` attribute, reinforcing C1):

| State | UI treatment | Writes |
|---|---|---|
| Available | No indicator (subtle green in header sync chip) | Enabled |
| Not signed into iCloud | Full-screen blocking onboarding + offer local-folder fallback | — |
| Container unavailable | Full-screen blocking w/ diagnostics + retry | — |
| Syncing (workspace) | Persistent header chip "Syncing…" | Disabled (matches locked sync-first write gate) |
| Local copy stale | Per-file row indicator + dismissible banner | Gated per-file |
| File missing locally (placeholder) | Per-file indicator + download affordance (`startDownloadingUbiquitousItem`) | Gated |
| Conflict detected | Banner + per-file indicator → resolution surface | Gated |

**Conflict resolution (the one hard part):** defer auto-merge entirely for v1.
Surface `NSFileVersion.unresolvedConflictVersions` with a plain "Keep mine / Keep
iCloud / Keep both" choice. Never silently merge finance files.

*Resolves:* `[DECIDE]` 7 sync states (Product) + the matching Design `[DECIDE]`
items (sync status indicators, first-launch onboarding iCloud states, loading/
indexing state). Consistent with the locked sync-first write gate (§21, R7).

---

## Phase 2 items adjacent to the three concerns (recommendations)

### D1. Import sign-flip detection — `[DECIDE]` Phase 2

**Recommendation:** **explicit per-import declaration** in the column-mapping step
(user states the source convention), with a heuristic *pre-fill* the user confirms.
Never silently flip — a sample window can mis-guess (e.g. an all-income month).
Matches "Safe writes / no surprises."

### D2. Validation rule catalog + issue classification — `[DECIDE]` Phase 2

**Recommendation — structure:** each rule = `{ id (VAL-<TIER>-<NNN>), tier,
severity, repair_class, message_template, predicate }`. Defaults for the
classification questions:
- Missing optional column → **warning**, auto-repair (inject empty column).
- Unknown `category_id` → **warning** (show "uncategorized"; don't block).
- Unknown `account_id` on a transaction → **error**, manual (offer assisted
  "create account," never silent auto-add).
- Missing required folder → **info**, auto-repair (create it).
- Severity philosophy: errors block projections/writes; warnings surface but don't
  block; info is silent/diagnostic.

This catalog should live as data alongside the B3 JSON schemas.

---

## Summary of recommended dispositions

| Item | Phase | Type | Recommendation |
|---|---|---|---|
| A1 iCloud entitlement + container ID | 1 | DECIDE + fix | One `iCloud.<bundle>` container; DEBUG local-folder provider; fix malformed ID |
| A2 Phase 0 env track | 1 | structure | Carve env-bootstrap sub-track |
| B1 manifest field set + location | 1 | DECIDE + fix | Device-local cache in App Support; pure index fields |
| B2 schema_version format | 2 | DECIDE | Leading `# schema_version` comment row; tolerant parser |
| B3 CSV spec gaps / S9 | 2 | DECIDE + fix | JSON schemas in `.finance-meta/schemas/`; encode enum/name map |
| B4 Account model shape | 1 | DECIDE | Single struct + optional `InvestmentMetadata?` |
| B5 OwnerDistribution | 1 | FIX-S5 | Remove from v1 |
| B6 savings-goal-contributions.csv | 2 | FIX-S4 | Remove; `savings_goal_id` is sole link |
| B7 goal status enum | 2 | FIX-S7 | `active \| archived`; reconcile core-domain note |
| C1 FileWatcherService | 1 | DECIDE | NSMetadataQuery (iCloud) + FSEvents (local) |
| C2 7 sync states UI | 1 | DECIDE | Mapping table above; defer conflict auto-merge |
| D1 import sign-flip | 2 | DECIDE | Explicit per-import declaration + heuristic pre-fill |
| D2 validation catalog | 2 | DECIDE | Rule schema + classification defaults |

**Three must-fix-before-code:** (1) container ID format [A1]; (2) manifest in the
sync path [B1]; (3) FileWatcher framing [C1].

---

## Next steps (R8 loop)

1. Principal confirms / adjusts the dispositions above.
2. Synthesize confirmed decisions into `r8-update-{doc}.md` plans per affected doc
   (`technical-design`, `architecture/*`, `product-roadmap`, `project-management`,
   `product-requirements` where the data model changes).
3. Apply cascading changes; retire resolved `[FIX]`/`[DECIDE]` items in
   `project-management.md`; add §21 lock entries for the newly-locked items.
4. Update `prototype/` and `_design/` if any storage/sync surfaces change.
