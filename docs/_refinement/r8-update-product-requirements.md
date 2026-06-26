---
round: 8
doc: product-requirements.md
date: 2026-06-26
status: APPLIED 2026-06-26 to canonical docs
source: docs/_refinement/r8-review.md (dispositions confirmed by principal 2026-06-26)
---

# R8 Update Plan — product-requirements.md

R8 is foundation-focused, so PRD changes are limited to data-model cleanup and a
reliability note.

## Data model

- Remove `OwnerDistribution` (`[FIX-S5]`) — owner-draw/business-equity accounting,
  no CSV spec, Business is a `group_type` not a module. Defer to V2.
- Remove the `GoalContribution` / `savings-goal-contributions` entity (`[FIX-S4]`);
  note `savings_goal_id` on the unified ledger is the sole budget-to-goal link.
- `SavingsGoal.status` → `active | archived` (`[FIX-S7]`).
- Apply the entity-naming reconciliation already tracked by `[FIX-M3]` / `[FIX-M6]`
  (single `Transaction`; drop `Personal/BusinessTransaction`, map the ~13 legacy PRD
  entities to their §10 equivalents). Do this here since the data-model table is being
  edited anyway.

## Non-goals / §4

- Align AI language (`[FIX-M5]`): change "AI model integrations to analyze
  performance" to "AI-driven analysis — **V2 deferred**" to match the roadmap.

## NFR — Reliability

- Add: iCloud conflicts are resolved manually via `NSFileVersion` (Keep mine / Keep
  iCloud / Keep both); no silent auto-merge.
- Add: the file index/manifest is a device-local regenerable cache (not synced), so a
  lost manifest never means lost data.

## Changelog
- Add Round 8 entry.

> Out of R8 scope (sweep separately): `[FIX-M1]` layer-count alignment, `[FIX-M2]`
> remove `ReportingEngine`, `[FIX-M4]` MVVM-vs-Observation wording — pure doc hygiene,
> not storage/sync/dev-env.
