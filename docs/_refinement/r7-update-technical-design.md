# Technical Design Update Plan — Round 7

Source: `docs/_refinement/r7-review.md` (MVP prep — architectural audit + R6 gap analysis + dev environment)
Target: `docs/technical-design.md`
Status: **Applied 2026-06-24** (direction provided inline; no separate proposal phase)

---

## Summary

Round 7 had two structural impacts on `technical-design.md`:

1. **Architecture split (A3)** — the file was reduced from ~1,600 lines to ~500 lines by extracting all
   detailed spec content (CSV schemas, validation rules, service responsibilities, data flows) into
   `docs/architecture/` (five new files). `technical-design.md` is now a lean overview that links out
   to those files. See `r7-update-architecture.md` for the extracted content.

2. **Locked decisions (§21)** — a new section recording all Phase 1–7 architectural decisions that have
   been locked. Round 6 decisions were already present; Round 7 added five new locked items.

No spec content changed in this round — all changes are structural or additive.

Items marked **⚠️ Verify** require code-level confirmation when the relevant phase is built.

---

## Change index

| # | Section | Type | Status |
|---|---|---|---|
| 1 | §6–§16 (bulk) | Extracted to `docs/architecture/` | ✅ Applied — ⚠️ Verify all cross-links |
| 2 | §21 — Locked decisions (R6 block) | Pre-existing; confirmed intact | ✅ Applied |
| 3 | §21 — Locked decisions (R7 block) | New section: 5 decisions added | ✅ Applied |
| 4 | Changelog | R7 entry appended | ✅ Applied |

---

## Detailed changes

### §6–§16 — Architecture extraction
The following sections were replaced with 2-line stubs linking to the relevant `docs/architecture/` file:
- §6 Workspace folder structure → `containers-and-budgets.md §1`
- §7 File naming conventions → `containers-and-budgets.md §1`
- §8 CSV file specifications (all 28 specs) → `containers-and-budgets.md §3`
- §9 Manifest format → abbreviated inline; links to `containers-and-budgets.md §2`
- §10 Internal data model → `core-domain.md §1`
- §11 Application architecture / module layout → `core-domain.md §2`
- §12 Service responsibilities → `core-domain.md §3`
- §13 Read pipeline / write pipeline → `data-pipelines.md §1`
- §14 Repair pipeline → `data-pipelines.md §1`
- §15 Validation rules → `rulesets-and-taxes.md §1`
- §16 UI requirements → `rulesets-and-taxes.md §2`

The extracted content is authoritative; `technical-design.md` stubs are navigation aids only.
- ⚠️ **Verify (ongoing)**: whenever a spec detail changes, update the relevant `docs/architecture/` file directly — do not add detail back to `technical-design.md`.

### §21 — Locked decisions (Round 7 additions)
Five new locked decisions added alongside the existing R6 block:

| Decision | Locked value |
|---|---|
| Business domain model | `group_type = business` under Accounts; no standalone BusinessEngine |
| Markdown viewer/editor | V2 only; front matter parsed in v1 |
| Sync-first write gate | `ICloudContainerService` exposes per-file sync state; writes disabled while syncing |
| Performance baseline | Apple Silicon M1+; older Intel acceptable with longer times |
| Tax module scope | Estimate payment obligations + organize documents; not a computation engine |

Additionally, the delete-on-reference decision (previously open in R6 locked block) was updated: ~~open~~ → **reassign** (locked R7).

- ⚠️ **Verify (Phase 1)**: sync-first write gate and ICloudContainerService implementation.
- ⚠️ **Verify (Phase 3)**: Business = group type in AccountEngine projections.
- ⚠️ **Verify (Phase 6)**: delete-on-reference reassign flow in WritePlanBuilder.

### Changelog
R7 entry appended covering: architecture split, §21 additions, prototype path fixes, and all direction decisions.

---

## Items explicitly NOT changed
- **§1–§5** (purpose, design goals, system overview, IA, sync states) — unchanged.
- **§9 manifest format** — abbreviated in place; not extracted (it is short and frequently referenced).
- **§21 Round 6 decisions** — confirmed intact; no changes needed.
- **Locked decisions from Rounds 1–5** — remain in §21 without change.

---

## Changelog stub (appended to technical-design.md)

```
### Round 7 — 2026-06-24
Source: docs/_refinement/r7-review.md (MVP prep — architectural audit + R6 gap analysis);
update plan docs/_refinement/r7-update-technical-design.md

- §6–§16: detailed spec content extracted to docs/architecture/ (five files: index.md,
  core-domain.md, containers-and-budgets.md, rulesets-and-taxes.md, data-pipelines.md);
  sections replaced with 2-line navigation stubs
- §21: five Round 7 locked decisions added (Business = group type; Markdown V2; sync-first write
  gate; M1+ performance baseline; tax scope guardrail); delete-on-reference updated from open to
  locked (reassign)
- Manifest JSON path example corrected to Accounts/transactions/2026-05.csv [FIX-C5]
- Advanced workspace mode marked as V2 [FIX-S8]
```
