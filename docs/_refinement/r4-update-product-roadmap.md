# Product Roadmap Update Plan — Round 4

Source: `docs/product-requirements.md` + `docs/technical-design.md` (post r4-review), `docs/_refinement/r4-review.md`
Target: `docs/product-roadmap.md`
Status: Proposed 2026-06-12

---

## Summary

Round 4 removes screens but keeps the underlying engines and data, so the roadmap impact is
small and concentrated in the **Design** and **Product** task lists — mostly the Phase 4
Savings/Investments and Taxes sections, plus the Phase 5 module views. No phase, milestone, or
development engine task is removed. The roadmap has no changelog section today; this round adds
one for traceability.

---

## Change index

| # | Section | Type | Impact |
|---|---|---|---|
| 1 | Out of Scope for v1 | Additions | Goal status states; dedicated sleeve/benchmark/payments/gains screens |
| 2 | Phase 4 → Product Tasks | Minor | Drop goal-status definition; note screen consolidation |
| 3 | Phase 4 → Design Tasks | Significant | Merge benchmark/sleeve design into Portfolio; fold estimated-payments design into tax overview |
| 4 | Phase 4 → Development Tasks | Confirm | Engines unchanged; SavingsGoalEngine drops status branching |
| 5 | Phase 5 → Module Views | Minor | S&I and Taxes view inventories shrink to match new screens |
| 6 | Open Decisions / Summary | Minor | Reflect resolved screen decisions |
| 7 | Changelog | New | Add changelog section |

---

## Detailed changes

### Out of Scope for v1

Add (with rationale from the review):
- Savings goal lifecycle states (active / archived) — V2 (general configurable dashboard)
- Dedicated sleeves screen — V2 (sleeve table remains on the Portfolio overview in v1)
- Dedicated benchmark screen — removed (heat map is a holdings-table toggle in v1)

Note that estimated payments and gains/income are **not** out of scope — they move into the
Current Tax Year view but stay in v1.

---

### Phase 4 — Product Tasks

**Savings & Investments**
- Remove/abridge any task that defines goal active/archived status — goals are a flat list in
  v1; status is V2.
- Keep portfolio allocation, benchmark-period, sector-weighting, and benchmark-import tasks —
  the heat-map functionality survives, only its surface changes (now a holdings toggle).

**Taxes**
- No removals. Add a note that realized gains, dividend/interest income, and estimated payments
  are presented within the Current Tax Year view rather than as dedicated screens.

---

### Phase 4 — Design Tasks

**Savings & Investments** — restructure the design tasks to match the holdings-focal Portfolio:
- **Goals overview**: remove active/archived grouping from goal-card design; flat list.
- **Portfolio overview** (replaces separate "Assets view" + "Benchmark heat map" + "Sleeve
  detail" tasks):
  - Holdings table as primary surface, with a **standard ⇄ heat-map view toggle**
  - Heat-map mode: 8 time periods × N accounts, color scale, S&P 500 comparison row, sector
    performance section
  - Sleeve table appended at the bottom: target vs actual weights, drift indicator,
    contribution target, linked strategy note
- Keep empty-state task.

**Taxes** — adjust:
- Fold the standalone **Estimated payments** design task into the **Tax overview / Current tax
  year** task (quarterly schedule shown inline).
- Fold realized gains / dividend-interest income presentation into the Current tax year task.
- **Tax prep checklist** design task: expand to a **full-width focal screen with educational
  content** explaining each step; ensure it is not part of the Current tax year layout.

---

### Phase 4 — Development Tasks

No engine is removed. Confirm and lightly amend:
- `SavingsGoalEngine` — drop any goal-status handling (flat active list in v1).
- `BenchmarkEngine`, `PortfolioEngine`, `TaxEngine` — unchanged; they still produce the data
  that now renders inside consolidated screens.

---

### Phase 5 — Module Views

Shrink the view inventories to match the new screen set:
- **Savings & Investments Module (`UI/SavingsInvestments/`)**: Overview, Goals (flat),
  Portfolio overview (holdings table + heat-map toggle + sleeve table). Remove separate
  Assets, Sleeves, and Benchmark views.
- **Taxes Module (`UI/Taxes/`)**: Current tax year (with payments + gains/income inline),
  Prep checklist (full-width, educational), Tax archive. Remove separate Estimated payments
  and Gains & income views.

---

### Open Decisions / Summary Table

- Mark the screen-consolidation questions as resolved by r4-review (Round 4) where they appear.
- Update any phase summary counts that enumerate module views to the reduced set.

---

## Changelog stub (new section to add to product-roadmap.md)

```
## Changelog

### Round 4 — 2026-06-12
Source: docs/_refinement/r4-review.md (second prototype review)

- Out of Scope: added goal active/archived states, dedicated sleeves screen, dedicated
  benchmark screen (sleeve table and heat map survive on the Portfolio overview)
- Phase 4 Design: replaced separate Assets / Benchmark / Sleeve tasks with a single
  holdings-focal Portfolio overview task (standard ⇄ heat-map toggle, sleeve table at bottom);
  folded Estimated payments and gains/income design into Current tax year; expanded prep
  checklist to a full-width educational screen
- Phase 4 Product/Dev: removed goal-status definition; SavingsGoalEngine drops status branching;
  all engines otherwise unchanged
- Phase 5: reduced Savings & Investments and Taxes module view inventories to the new screen set
```

> Note: a stray reference at line ~451 ("Finalize Overview dashboard wireframe (updated post
> Round 1)") can stay; it predates this round and is unaffected.
