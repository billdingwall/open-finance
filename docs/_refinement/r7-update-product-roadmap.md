# Product Roadmap Update Plan — Round 7

Source: `docs/_refinement/r7-review.md` (MVP prep — architectural audit + R6 gap analysis + dev environment)
Target: `docs/product-roadmap.md`
Status: **Applied 2026-06-24** (direction provided inline; no separate proposal phase)

---

## Summary

Round 7 made four targeted changes to the roadmap: added an explicit V2 tracking entry for live
market data, resolved the last open Phase 6 decision (delete-on-reference), added a prototype
write/edit task to Phase 6 Design, and added a Phase 6 Design entry for dev environment setup.
No phase structure or milestone gates changed.

Items marked **⚠️ Verify** require execution or confirmation before advancing phases.

---

## Change index

| # | Section | Type | Status |
|---|---|---|---|
| 1 | Out of Scope table | V2 tracking entry added | ✅ Applied |
| 2 | Open Decisions table | Delete-on-reference resolved | ✅ Applied |
| 3 | Phase 1 Development — Xcode Setup | CI/CD note added (SwiftLint, GitHub Actions) | ✅ Applied |
| 4 | Phase 6 Design | Prototype write/edit flow task added | ✅ Applied — ⚠️ Pending execution [FIX-R7-P1] |
| 5 | Changelog | R7 entry appended | ✅ Applied |

---

## Detailed changes

### Out of Scope table
- **Added row**: "Live price ingestion strategy (endpoint choice, polling interval, error handling) | V2"
- Clarifies that real-time market data (already listed) and the ingestion strategy for it are both deferred. Source: A5.

### Open Decisions table
- **Updated**: delete-on-reference row — status changed from open to "Locked Round 7 — reassign." The decision was open from R5/R6 and is now resolved: surface referencing rows, per-collection picker, atomic delete + reassignments.
- Source: B1.

### Phase 1 Development — Xcode Project Setup
- **Added** context to SwiftLint task: GitHub Actions, SwiftLint runs on a standard Linux runner in Phase 1. Full Mac build CI deferred to Phase 5.
- Source: E3.

### Phase 6 Design
- **Added task**: "Update prototype to demonstrate write/edit/delete flows and write-preview: add transaction modal, edit account side panel, delete with reference-check reassignment preview, import CSV column-mapping flow."
- This task is tracked as `[FIX-R7-P1]` in `docs/project-management.md`.
- ⚠️ **Pending execution**: prototype write/edit flows have not been implemented. This is the primary outstanding R7 execution task.
- Source: A2, B2.

### Changelog
R7 entry appended.

---

## Items explicitly NOT changed
- **Phase structure and milestone gates** — unchanged.
- **Phase 1–5 task lists** — no additions beyond CI/CD note.
- **Phase 6–7 task lists** — only the one prototype design task added.
- **Milestone conditions** — unchanged.
- **Phase dependencies overview** — unchanged.

---

## Changelog stub (appended to product-roadmap.md)

```
### Round 7 — 2026-06-24
Source: docs/_refinement/r7-review.md (MVP prep — architectural audit + R6 gap analysis);
update plan docs/_refinement/r7-update-product-roadmap.md

- Out of Scope: added "Live price ingestion strategy" as explicit V2 tracked item
- Open Decisions: delete-on-reference resolved — locked as reassign (surface referencing rows,
  per-collection picker, atomic write)
- Phase 1 Development: SwiftLint task updated with CI/CD context (GitHub Actions, Linux runner)
- Phase 6 Design: prototype write/edit flow task added [FIX-R7-P1] — pending execution
- Phase 2 Development: migrate-r6.swift task added (one-time R6 schema migration)
```
