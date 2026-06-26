---
round: 8
doc: architecture/* (core-domain, containers-and-budgets, data-pipelines, rulesets-and-taxes)
date: 2026-06-26
status: APPLIED 2026-06-26 to canonical docs
source: docs/_refinement/r8-review.md (dispositions confirmed by principal 2026-06-26)
---

# R8 Update Plan — architecture/

One plan covering all four `docs/architecture/` files (matches the R7 single-
architecture-plan pattern).

## core-domain.md

**§2 Module layout / recommended stack**
- Add the DEBUG local-folder provider note (mirrors technical-design §5).

**§3 Service responsibilities**
- **ICloudContainerService**: state that the per-file sync state (`available`,
  `downloading`, `uploading`, `conflict`, `error`) is **derived from `NSMetadataQuery`**
  attributes (`NSMetadataUbiquitousItemDownloadingStatusKey`, percent-downloaded,
  upload/download-in-progress, conflict flags). Add conflict handling = manual via
  `NSFileVersion.unresolvedConflictVersions` (no auto-merge).
- **FileWatcherService**: replace the "DispatchSource or NSFilePresenter" framing —
  specify **`NSMetadataQuery` for the iCloud provider** and **FSEvents for the
  local-folder provider**. `NSFileCoordinator`/`NSFilePresenter` = read/write
  coordination only.
- **Add three missing service specs (`[FIX-S6]`):**
  - `FileCoordinatorService` — wraps `NSFileCoordinator` for iCloud-safe coordinated
    reads/writes; serializes concurrent access at the OS level.
  - `ManifestStore` — reads/writes the device-local manifest in Application Support
    (`~/Library/Application Support/OpenFinance/<workspace_id>/manifest.json`);
    maintains last-indexed snapshot + per-file index/validation cache; rebuilds from
    scan if missing/corrupt.
  - `SettingsStore` — reads/writes `Taxes/settings.csv`; exposes typed
    `WorkspaceSettings` observable.
- **SavingsGoalEngine (`[FIX-S7]`)**: replace "no goal lifecycle states in v1 — every
  goal is active" with a minimal **`active | archived`** lifecycle; `completed` is
  derived (progress ≥ target), `paused` not in v1. Engine branches only on archived.

**§2 Notes / Account model (`[DECIDE]` Account shape)**
- Confirm: `Account` is a single struct; investment-specific fields live in an
  optional nested `InvestmentMetadata?`, not a separate `InvestmentAccount` type.

## containers-and-budgets.md

**§3 preamble (new)**
- State the **schema_version convention**: every managed CSV begins with a
  `# schema_version: N` comment row; the parser strips leading `#` lines.
- State that **machine-readable JSON schemas live in `.finance-meta/schemas/`** and
  are the single source of truth driving `CSVSchemaRegistry`, `ValidationEngine`,
  bootstrap templates, and migrations (`[DECIDE]` CSV spec gaps — format/approach
  resolved; per-file enum enumeration remains Phase 2 work).

**§1 folder structure / Budget specs (`[FIX-S4]`)**
- Remove `Budget/savings-goal-contributions.csv`. Confirm `savings_goal_id` on the
  unified transaction ledger is the **sole** budget-to-goal linking mechanism.

**goals.csv spec (`[FIX-S7]`)**
- Define `status` enum values: `active | archived`.

**accounts / account-groups spec (`[FIX-S9]`)**
- Add the display-name ↔ enum mapping (encode in the JSON schema): "Everyday
  Banking" → `checking`, "Credit Cards" → `credit_card`, "Loans & Debt" → `loan`,
  etc.

**Registry alignment (`[FIX R6-M1…M4]`)**
- Confirm the JSON schemas reflect the R6 renames/additions: `account-groups.csv`,
  `assets.csv`, `tax-adjustments.csv`, `liabilities.csv`, `portfolios.csv` + sleeves,
  and the `group_id`/`group_role` columns on the unified transaction schema.

## data-pipelines.md

**§1 / §3 flows**
- Update manifest-write steps (FileIndexService) to target the Application Support
  location, not `.finance-meta/`.

**§3.1 import pipeline (`[DECIDE]` sign-flip)**
- Specify `CSVNormalizer` sign detection = **explicit per-import declaration** in the
  column-mapping step, with a heuristic **pre-fill** the user confirms. Never silently
  flip.

**§2 scripts**
- Note `bootstrap-workspace` reads the `.finance-meta/schemas/` JSON schemas to emit
  templates (single source of truth).

## rulesets-and-taxes.md

**New section — Validation rule catalog (`[DECIDE]` catalog + classification)**
- Rule shape: `{ id: VAL-<TIER>-<NNN>, tier (file|cross-file|domain), severity
  (error|warning|info), repair_class (auto|manual|none), message_template, predicate }`.
- Catalog stored as data alongside the JSON schemas.
- Classification defaults:
  - Missing optional column → warning, auto-repair (inject empty column).
  - Unknown `category_id` → warning (show "uncategorized"; don't block).
  - Unknown `account_id` on a transaction → error, manual (assisted "create account",
    never silent auto-add).
  - Missing required folder → info, auto-repair (create it).
- Severity philosophy: errors block projections/writes; warnings surface; info silent.
- Note: structure + defaults resolved here; full per-rule enumeration remains Phase 2.
