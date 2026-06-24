# Product Requirements Update Plan — Round 7

Source: `docs/_refinement/r7-review.md` (MVP prep — architectural audit + R6 gap analysis + dev environment)
Target: `docs/product-requirements.md`
Status: **Applied 2026-06-24** (direction provided inline; no separate proposal phase)

---

## Summary

Round 7 applied six targeted requirement changes to the PRD. The changes are concentrated in
§4 (Markdown V2 lock), §8 (tax scope guardrail), §12 (delete-on-reference policy), the NFRs
(M1+ performance baseline, sync-first write reliability), and the Technical Architecture section
(domain layer cleanup). Non-goals wording was tightened for tax computation and AI integrations.

No new screens or navigation changes. No CSV-spec or data-model changes (those were R6). This
round locks scope and adds execution guardrails.

Items marked **⚠️ Verify** require code-level confirmation when the relevant phase is built.

---

## Change index

| # | Section | Type | Status |
|---|---|---|---|
| 1 | §4 Notes & Markdown | Scope lock — V2 deferral | ✅ Applied |
| 2 | §5 Accounts / Business | Clarification — group type | ✅ Applied — ⚠️ Verify when AccountEngine built (Phase 3) |
| 3 | §8 Tax module | Guardrail added | ✅ Applied |
| 4 | §12 Object management | Delete-on-reference policy locked | ✅ Applied — ⚠️ Verify when write flows built (Phase 6) |
| 5 | NFR Performance | M1+ hardware baseline added | ✅ Applied |
| 6 | NFR Reliability | Sync-first write safety requirement | ✅ Applied — ⚠️ Verify when ICloudContainerService built (Phase 1) |
| 7 | Technical Architecture | Domain layer listing cleaned up | ✅ Applied — ⚠️ Verify against final module layout (Phase 3) |
| 8 | Non-goals | Tax and AI wording tightened | ✅ Applied |

---

## Detailed changes

### §4 Notes & Markdown
- **Removed**: "provide a readable native viewer in v1" requirement.
- **Added**: V2 deferral statement — Markdown viewer and editor are V2 only. In v1, `.md` files are parsed for front matter metadata only (note type, linked entities, period); no body rendering in the app UI.
- Source: B4. Resolves [FIX-S1] inconsistency across PRD/roadmap/scope list.

### §5 Accounts module — Business
- **Added**: clarification that Business is a `group_type = business` account group managed through the account-group system. There is no standalone Business module; business P&L is owned by `AccountEngine`.
- ⚠️ **Verify (Phase 3)**: confirm `AccountEngine` projections correctly scope to `group_type = business` rows for monthly P&L, category variance, and expense summaries.
- Source: B3.

### §8 Tax module — scope guardrail
- **Added** (before Requirements): explicit guardrail paragraph stating the two primary goals — (1) estimate tax payment obligations based on income types, (2) organize tax documents and the prep checklist. The module is not a tax computation engine; all figures are estimates.
- **Updated** non-goal: "Tax return filing" → "Tax return filing or tax computation engine (see §8 tax scope guardrail)."
- Source: C5.

### §12 Object management — delete-on-reference
- **Added** full reassign policy under the delete requirement:
  1. Surface all referencing rows grouped by collection with counts.
  2. Show a per-collection reassignment picker (or "leave unlinked" for nullable references).
  3. Write the deletion and all reassignments atomically — no partial state.
- ⚠️ **Verify (Phase 6)**: confirm `WritePlanBuilder` implements the atomic write and that the reassignment preview panel surfaces the correct referencing rows for each entity type.
- Source: B1.

### NFR Performance
- **Added** bullet: "Target hardware: Apple Silicon Macs (M1 or newer). Longer processing times on older Intel hardware are acceptable and not a defect."
- Source: C2 (R7 locked decision).

### NFR Reliability
- **Added** sync-first write safety requirement: app checks workspace sync state before enabling write actions; write actions are disabled while sync state is `syncing` or any targeted file is `downloading`; `WritePlanBuilder` gates on per-file sync state before building any write plan. References `docs/architecture/core-domain.md §3` (ICloudContainerService) for implementation detail.
- ⚠️ **Verify (Phase 1)**: confirm `ICloudContainerService.syncState(for:)` is exposed and `WritePlanBuilder` queries it on every write attempt.
- Source: C1.

### Technical Architecture — Domain Layer
- **Removed**: `ReportingEngine`, `BusinessEngine` from domain layer listing. (ReportingEngine is covered by ExportService in Phase 6; BusinessEngine is not a standalone module — see B3.)
- **Added**: `BenchmarkEngine`, `TaxAdjustmentEngine`, `TaxPrepEngine`, `OverviewEngine` to domain layer listing.
- **Added** note: Business is a group type under Accounts — `AccountEngine` handles all business P&L; no separate BusinessEngine.
- ⚠️ **Verify (Phase 3–4)**: confirm PRD domain layer listing matches the final `docs/architecture/core-domain.md §2` module layout once engines are implemented.
- Source: B3, A3.

### Non-goals
- "AI model integrations to analyze performance" updated to "AI model integrations to analyze performance (V2 deferred)" to match roadmap out-of-scope language.
- Source: A5/[FIX-M5].

---

## Items explicitly NOT changed
- **Navigation and screen structure** — unchanged from R6.
- **Data model / CSV schemas** — R6 covered this; R7 made no schema changes.
- **PRD §5 display name → enum mapping** — [FIX-S9] remains open (account group display names vs enum values).
- **OwnerDistribution scope** — [FIX-S5] remains open.
- **PRD data model entity table** — [FIX-M3] reconciliation with Tech Design §10 remains open.
- **MVVM vs Observation** — [FIX-M4] remains open.

---

## Changelog stub (appended to product-requirements.md)

```
### Round 7 — 2026-06-24
Source: docs/_refinement/r7-review.md (MVP prep — architectural audit + R6 gap analysis);
update plan docs/_refinement/r7-update-product-requirements.md

- §4: Markdown viewer/editor deferred to V2; front matter only parsed in v1
- §5: Business clarified as group_type = business under Accounts; no standalone module
- §8: Tax scope guardrail added — primary goals are estimating tax payment obligations and
  organizing documents; not a computation engine
- §12: Delete-on-reference policy locked as reassign — surface referencing rows, per-collection
  picker, atomic write of delete + reassignments
- NFR Performance: Apple Silicon M1+ as target hardware baseline
- NFR Reliability: sync-first write safety requirement added; references core-domain.md §3
- Technical Architecture: domain layer listing updated (ReportingEngine/BusinessEngine removed;
  BenchmarkEngine/TaxAdjustmentEngine/TaxPrepEngine/OverviewEngine added)
- Non-goals: AI integrations noted as V2 deferred; tax computation engine explicitly excluded
```
