---
round: 8
doc: project-management.md
date: 2026-06-26
status: APPLIED 2026-06-26 to canonical docs
source: docs/_refinement/r8-review.md (dispositions confirmed by principal 2026-06-26)
---

# R8 Update Plan — project-management.md

Retire resolved items (strike-through, keep for history), add the small amount of new
work R8 creates, and recompute the counts table.

## Phase 1 — retire

- `[DECIDE]` iCloud entitlement strategy → **Resolved R8**: single `iCloud.<bundle-id>`
  container across dev/dist; DEBUG local-folder provider; bare-`OpenFinance` ID
  corrected.
- `[DECIDE]` 7 iCloud sync states → **Resolved R8**: UI-treatment table + conflict UX
  (manual, `NSFileVersion`). See technical-design §5.
- `[DECIDE]` manifest field set → **Resolved R8**: device-local cache in Application
  Support; field set defined.
- `[DECIDE]` FileWatcherService implementation → **Resolved R8**: NSMetadataQuery
  (iCloud) + FSEvents (local).
- `[DECIDE]` Account model shape → **Resolved R8**: single struct + optional
  `InvestmentMetadata?`.
- `[FIX-S5]` OwnerDistribution → **Resolved R8**: removed from v1.
- `[FIX-S9]` group display-name→enum map → **Resolved R8**: encoded in JSON schema.
- `[FIX-S6]` FileCoordinator/Manifest/Settings service specs → **Resolved R8**: added
  to core-domain §3.
- `[FIX-C6]` rename BusinessEntity, `[FIX-M3]` / `[FIX-M6]` entity reconciliation →
  **Resolved R8** via the PRD data-model cleanup.

## Phase 2 — retire / partial

- `[DECIDE]` schema_version header format → **Resolved R8**: leading comment row.
- `[DECIDE]` import sign-flip detection → **Resolved R8**: explicit per-import
  declaration + heuristic pre-fill.
- `[FIX-S4]` savings-goal-contributions.csv → **Resolved R8**: removed; `savings_goal_id`
  is sole link.
- `[FIX-S7]` goal status enum → **Resolved R8**: `active | archived`.
- `[FIX R6-M1…M4]` schema renames/additions → **Resolved R8**: reflected in the
  `.finance-meta/schemas/` JSON schemas.
- `[DECIDE]` CSV spec gaps → **Partially resolved R8**: format/approach decided
  (comment-row + JSON schemas as source of truth); **remaining**: enumerate every enum
  set + required/optional per file. Keep open, re-scoped.
- `[DECIDE]` validation rule catalog → **Partially resolved R8**: rule shape +
  classification defaults locked; **remaining**: enumerate the full per-rule catalog.
  Keep open, re-scoped.
- `[DECIDE]` validation issue classification → **Resolved R8**: defaults table set.

## New items to add

- `[TASK]` Phase 0: author the env-bootstrap checklist (entitlement, local-folder dev
  provider, `fixture-generate`, CI smoke test for dual-mode workspace resolution).
- `[TASK]` Phase 2: author the 28 JSON schemas in `.finance-meta/schemas/` (drives
  registry, validation, bootstrap, migration).
- `[FIX R6-M5]` migrate-r6 script — unchanged, remains open.

## Counts table
- Recompute after retirements: Phase 1 open drops by ~9 (5 DECIDE + 4 FIX); Phase 2
  open drops by ~6 net (account for the two re-scoped partials staying open + two new
  TASKs). Recompute exact totals when applying.

> Out of R8 scope (remain open as doc hygiene): `[FIX-M1]`, `[FIX-M2]`, `[FIX-M4]`,
> `[FIX-M5]`. `[FIX-M5]` (AI language) will close via the PRD plan if that edit lands.
