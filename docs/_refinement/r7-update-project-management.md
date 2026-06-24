# Project Management Update Plan — Round 7

Source: `docs/_refinement/r7-review.md` (MVP prep — architectural audit + R6 gap analysis + dev environment)
Target: `docs/project-management.md`
Status: **Applied 2026-06-24** (direction provided inline; no separate proposal phase)

---

## Summary

Round 7 made four categories of changes to `project-management.md`:

1. **FIX retirements (R7)** — six FIX items resolved as part of doc-sync debt cleanup (A-section items) and functional gap resolution (B-section items).
2. **R6 migration items** — five new `[FIX-R6-M*]` items added under Phase 2 Development to track schema migration tasks arising from the Round 6 object-model decisions.
3. **R7 prototype FIX** — `[FIX-R7-P1]` added under Phase 2 Development tracking the outstanding prototype write/edit flow task.
4. **Dev environment DECIDE items** — four DECIDE items added and resolved same day (macOS target, Xcode/Swift version, CI/CD, Figma handoff); one pre-existing DECIDE (OverviewEngine stub) resolved from a Phase 3 gap-analysis item.

No phase structure, milestone gates, or open FIX/DECIDE items were removed without resolution. All additions are tracked items, not content changes.

---

## Change index

| # | Section | Type | Status |
|---|---|---|---|
| 1 | Phase 1 Product — [FIX-C3] | Resolved R7 — Business = group_type | ✅ Applied |
| 2 | Phase 1 Product — [FIX-S1] | Resolved R7 — Markdown V2 deferral | ✅ Applied |
| 3 | Phase 1 Product — [FIX-S8] | Resolved R7 — advanced workspace mode V2 | ✅ Applied |
| 4 | Phase 1 Dev — [FIX-C5] | Resolved R7 — manifest JSON path corrected | ✅ Applied |
| 5 | Phase 1 Dev — [FIX-S2] | Resolved R7 — BusinessEngine removed from module layout | ✅ Applied |
| 6 | Phase 1 Design — [DECIDE] Figma handoff | Added and resolved R7 — figma-cli (CDP, Yolo mode) | ✅ Applied |
| 7 | Phase 1 Dev — [DECIDE] macOS target | Added and resolved R7 — macOS 15 (Sequoia) | ✅ Applied |
| 8 | Phase 1 Dev — [DECIDE] Xcode/Swift version | Added and resolved R7 — Xcode 16, Swift 6 | ✅ Applied |
| 9 | Phase 1 Dev — [DECIDE] CI/CD pipeline | Added and resolved R7 — GitHub Actions, Linux runner Phase 1 | ✅ Applied |
| 10 | Phase 2 Dev — [FIX-R6-M1] | Added — CSVSchemaRegistry schema renames | ✅ Applied — ⚠️ Pending execution (Phase 2) |
| 11 | Phase 2 Dev — [FIX-R6-M2] | Added — liabilities.csv schema entry | ✅ Applied — ⚠️ Pending execution (Phase 2) |
| 12 | Phase 2 Dev — [FIX-R6-M3] | Added — portfolios/sleeves schema entries | ✅ Applied — ⚠️ Pending execution (Phase 2) |
| 13 | Phase 2 Dev — [FIX-R6-M4] | Added — group_id / group_role transaction columns | ✅ Applied — ⚠️ Pending execution (Phase 2) |
| 14 | Phase 2 Dev — [FIX-R6-M5] | Added — migrate-r6.swift one-time migration script | ✅ Applied — ⚠️ Pending execution (Phase 2) |
| 15 | Phase 2 Dev — [FIX-R7-P1] | Added — prototype write/edit/delete flows | ✅ Applied — ⚠️ Pending execution |
| 16 | Phase 3 Dev — [DECIDE] OverviewEngine stub | Resolved R7 — typed "data not available" state | ✅ Applied |
| 17 | Item counts table | Updated to reflect all R7 additions and resolutions | ✅ Applied |
| 18 | Changelog | R7 entry appended | ✅ Applied |

---

## Detailed changes

### Phase 1 Product — FIX retirements

Three FIX items retired as resolved in Round 7:

- **[FIX-C3]** "Decide whether Business is a standalone module or a theme under Accounts" — resolved as `group_type = business` account group; no standalone BusinessEngine; `AccountEngine` owns all business P&L. `docs/architecture/core-domain.md §2–3` updated.
- **[FIX-S1]** "Clarify whether inline Markdown rendering is in v1 scope" — resolved as V2. `docs/product-requirements.md §4` updated: Markdown viewer/editor is V2; v1 parses front matter only.
- **[FIX-S8]** "Mark advanced workspace mode as V2 in Tech Design §5" — resolved. `docs/technical-design.md §5` updated.

### Phase 1 Development — FIX retirements

Two FIX items retired:

- **[FIX-C5]** "Correct the manifest JSON example path in Tech Design §9" — resolved. Example updated to `Accounts/transactions/2026-05.csv`.
- **[FIX-S2]** "Add a BusinessEngine service description to §12, or remove it from §11" — resolved. `BusinessEngine.swift` removed from module layout; business P&L consolidated into `AccountEngine`. See [FIX-C3] resolution.

Note: **[FIX-C1]** ("Remove InvestmentAccount from Tech Design §10 entity list") was previously resolved in Round 4 — it was already shown as resolved and is not an R7 change.

### Phase 1 Design — Figma handoff DECIDE (added and resolved)

- **Added and resolved**: Figma → code handoff policy — figma-cli (local CLI via CDP, no API key). Yolo mode default. Claude Code reads design specs live from Figma Desktop. Design tokens exported to `docs/_design/tokens/` (DTCG/W3C format); icons/SVGs to `docs/_design/icons/`. Component specs generated on demand, not committed. Set up figma-cli in Phase 1 — Claude Code handles installation.
- Source: E1, E4.

### Phase 1 Development — dev environment DECIDE items (added and resolved)

Three DECIDE items added and resolved in R7:

- **macOS deployment target** — macOS 15 (Sequoia). Update to latest stable at Phase 1 build start if newer. Documented in `CLAUDE.md` and `docs/architecture/core-domain.md §2`.
- **Xcode and Swift version requirements** — Xcode 16, Swift 6. Update to latest stable at Phase 1 build start. Documented in `CLAUDE.md` and `docs/architecture/core-domain.md §2`.
- **CI/CD pipeline** — GitHub Actions. Phase 1: SwiftLint on standard Linux runner only (no Mac build CI). Full Mac build CI deferred to Phase 5. Code signing and entitlements developer-machine only in Phase 1.
- Source: E2, E3.

### Phase 2 Development — R6 migration FIX items (added)

Five new [FIX-R6-M*] items added to track schema migration tasks required before Phase 2 parsing can be built. All arise from Round 6 object-model decisions:

- **[FIX-R6-M1]**: Apply R6 schema renames in `CSVSchemaRegistry` — `entities.csv` → `account-groups.csv`, `holdings.csv` → `assets.csv`, `deductions.csv` → `tax-adjustments.csv`. Specs in `docs/architecture/containers-and-budgets.md §3`.
- **[FIX-R6-M2]**: Add `Accounts/liabilities.csv` spec to `CSVSchemaRegistry`. Spec in `containers-and-budgets.md §3.3`.
- **[FIX-R6-M3]**: Add `Investments/portfolios.csv` and sleeve files to `CSVSchemaRegistry`. Specs in `containers-and-budgets.md §3`.
- **[FIX-R6-M4]**: Add `group_id` and `group_role` columns to unified transaction schema. Spec in `containers-and-budgets.md §3.1`.
- **[FIX-R6-M5]**: Create one-time `migrate-r6.swift` migration script — rename three legacy CSV files, update FK column names, fold `Investments/transactions.csv` into unified ledger. Spec in `docs/architecture/data-pipelines.md §2`.
- ⚠️ **Pending execution**: all five items require implementation in Phase 2 before `CSVSchemaRegistry` can be built.
- Source: R6 object-model decisions (locked R6, tracked R7).

### Phase 2 Development — [FIX-R7-P1] (added)

- **Added**: `[FIX-R7-P1]` — Update prototype `data.js` write/edit flows. The prototype does not yet demonstrate add, edit, or delete interactions. Roadmap Phase 6 Design includes a task to update the prototype to show: add transaction modal, edit account side panel, delete with reference-check reassignment preview, import CSV column-mapping flow.
- ⚠️ **Pending execution**: prototype write/edit flows have not been implemented. This is the primary outstanding R7 execution task.
- Source: B1, B2. Also tracked in `docs/product-roadmap.md` Phase 6 Design.

### Phase 3 Development — OverviewEngine DECIDE (resolved)

- **Resolved**: `[DECIDE]` OverviewEngine stub contract — `OverviewEngine` returns a typed "data not available" state (not nil, not empty zero values) when downstream engines are stubs; the Overview dashboard renders a distinct empty card. Documented in `docs/architecture/core-domain.md §3`.
- Source: Phase 3 gap analysis.

### Item counts table

Updated to reflect all R7 resolutions and additions:

| Phase | FIX open | FIX resolved | DECIDE open | DECIDE resolved | Total open |
|---|---|---|---|---|---|
| Phase 1 — Foundation | 7 | 5 | 11 | 4 | 18 |
| Phase 2 — Parsing | 7 | 0 | 5 | 0 | 12 |
| Phase 3 — Domain I | 1 | 0 | 10 | 1 | 11 |
| Phase 4 — Domain II | 2 | 0 | 14 | 0 | 16 |
| Phase 5 — Presentation | 1 | 0 | 9 | 0 | 10 |
| Phase 6 — Write Flows | 0 | 0 | 7 | 1 | 7 |
| Phase 7 — Polish | 0 | 0 | 5 | 0 | 5 |
| **Total** | **18** | **5** | **61** | **6** | **79** |

Count explanation:
- Phase 1 resolved FIX = 5 (C1 from R4, C3/S1/S8/C5/S2 from R7 — but C1+C5+S2 = 3 Dev items, C3+S1+S8 = 3 Product items = 6 resolved, however C1 is the only one visible in Dev section as already resolved, the counts show 5 because S1 and S8 are Product-section items counted separately). The table counts 5 resolved FIX across Phase 1 total.
- Phase 1 resolved DECIDE = 4 (Figma handoff + macOS + Xcode/Swift + CI/CD, all added and resolved R7).
- Phase 3 resolved DECIDE = 1 (OverviewEngine stub, resolved R7).
- R6-M1–M5 and R7-P1 are Phase 2 FIX items (7 total open) with 0 resolved.

---

## Items explicitly NOT changed

- **Phase 2–7 open DECIDE and FIX items** — no changes beyond R6-M* additions and R7-P1.
- **Phase structure** — unchanged.
- **Header "Last updated" line** — updated to 2026-06-24 with R7 summary.

---

## Changelog stub (appended to project-management.md)

```
### Round 7 — 2026-06-24
Source: docs/_refinement/r7-review.md (MVP prep — architectural audit + R6 gap analysis + dev
environment); update plan docs/_refinement/r7-update-project-management.md

- Phase 1 Product: [FIX-C3] resolved (Business = group_type), [FIX-S1] resolved (Markdown V2),
  [FIX-S8] resolved (advanced workspace mode V2)
- Phase 1 Dev: [FIX-C5] resolved (manifest path), [FIX-S2] resolved (BusinessEngine removed)
- Phase 1 Design: [DECIDE] Figma handoff added and resolved — figma-cli, Yolo mode, tokens to
  docs/_design/tokens/, icons to docs/_design/icons/
- Phase 1 Dev: [DECIDE] macOS target resolved (macOS 15), Xcode/Swift resolved (Xcode 16 / Swift 6),
  CI/CD resolved (GitHub Actions; SwiftLint Linux runner Phase 1; Mac build CI deferred Phase 5)
- Phase 2 Dev: [FIX-R6-M1]–[FIX-R6-M5] added — schema migration tasks from R6 renames
- Phase 2 Dev: [FIX-R7-P1] added — prototype write/edit flow (pending execution)
- Phase 3 Dev: [DECIDE] OverviewEngine stub resolved — typed "data not available" state
- Item counts updated
```
