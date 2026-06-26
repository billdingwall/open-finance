---
round: 8
doc: product-roadmap.md
date: 2026-06-26
status: APPLIED 2026-06-26 to canonical docs
source: docs/_refinement/r8-review.md (dispositions confirmed by principal 2026-06-26)
---

# R8 Update Plan — product-roadmap.md

## New — Phase 0 (Project & Environment Bootstrap) sub-track

Add a Phase 0 sub-track at the front of Phase 1 (no global renumber — express as a
Phase 1 "Setup" sub-track or a Phase 0 heading before §"Phase 1"). Checklist:
- Configure ubiquity-container entitlement with the corrected `iCloud.<bundle-id>`
  identifier; local-dev code signing.
- Implement the **DEBUG local-folder `CloudStorageProvider`** rooted at `~/Finance-Dev/`.
- `fixture-generate` script → realistic 12-month dataset in `~/Finance-Dev/`.
- SwiftLint + GitHub Actions (already locked) wired and green.
- Smoke test: workspace URL resolves in **both** iCloud and local-folder modes (this is
  the existing Phase 1 advancement gate, made explicit here).

## Phase 1 edits

**Platform Layer**
- `ICloudContainerService` task: add NSMetadataQuery-sourced sync states + conflict
  handling via `NSFileVersion`.
- `FileWatcherService` task: change "use `DispatchSource` or `NSFilePresenter`" to
  **`NSMetadataQuery` (iCloud) + FSEvents (local)**.
- `ManifestStore` task: read/write the **Application Support** manifest location, not
  `.finance-meta/`.

**Product Tasks**
- "Finalize iCloud entitlement strategy" → mark resolved; note corrected identifier
  format and single-container decision.
- "Document the 7 required iCloud sync states" → mark resolved; reference the §5 table.
- "Define the `.finance-meta/manifest.json` shape" → update to Application Support
  location + R8 field set.

**Core Data Models**
- Remove `OwnerDistribution` from the entity list (`[FIX-S5]`).
- `Account` note: single struct + optional `InvestmentMetadata?`.

## Phase 2 edits

- CSV file specs task: note schema_version = leading comment row; schemas authored as
  JSON in `.finance-meta/schemas/` (source of truth).
- Remove `savings-goal-contributions.csv` references (`[FIX-S4]`).
- `goals.csv` validation: `status ∈ {active, archived}` (`[FIX-S7]`).
- `CSVNormalizer` task: sign-flip = explicit per-import declaration + heuristic pre-fill.
- Validation engine task: adopt the rule-catalog shape + classification defaults from
  `architecture/rulesets-and-taxes.md`.

## Changelog
- Add Round 8 entry.
