# PRD Update Plan — Round 2

Source review: `docs/_refinement/review-r2.md`
Target: `docs/product-requirements.md`
Status: Proposed 2026-06-12

---

## Summary

Round 2 is the second prototype review. It is a **scope-trimming pass**: seven screens are
removed from MVP (most fold their content into a sibling screen, none lose underlying
functionality), and four screens are re-focused so a single primary surface dominates.

Note on drift: the doc changelogs and the prototype are out of sync. The Round 3 sidebar
refinement (2026-06-10) already removed several of these items from the *sidebar navigation*
in `technical-design.md`. Round 2 here finishes the cut in the PRD's *content* sections and
realigns the prototype. Where a change is already reflected, it is marked **(already aligned)**.

Two clarifications from the review author, encoded below:
- **Gains & Income**: remove the *dedicated screen only*. Realized gains and dividend/interest
  income remain in MVP scope, surfaced within the Current Tax Year view.
- **Sleeves**: keep "Portfolio" as the overview screen and append the sleeve table to the
  bottom of it. The dedicated sleeve screen is removed.

---

## Section-by-Section Changes

### Scope — In scope for v1 / Out of scope for v1

The review removes screens but keeps most functionality. Only the dedicated-screen concept
moves; the data and calculations stay. The one genuine scope change is removing the *notion of
goal status* (active/archived) from MVP.

**Changes to PRD:**
- In scope: no module is removed wholesale. Re-frame Savings & Investments and Taxes as
  fewer, denser screens (see §7 and §8 below).
- Out of scope for v1 (add, with "general configurable dashboard" rationale where the review
  says so):
  - Savings goal lifecycle states (active / archived goals) — V2
  - Dedicated sleeves screen — V2 (sleeve *table* stays on Portfolio overview in v1)
  - Dedicated benchmark screen — removed (heat map moves onto the holdings table)
  - Dedicated estimated-payments screen — removed (covered within Current Tax Year)
  - Dedicated gains & income screen — removed (covered within Current Tax Year)
  - Accounts screen under Savings & Investments — removed (duplicated Portfolio overview)

---

### Information architecture

The Savings & Investments and Taxes sidebars lose items. Most are **(already aligned)** in
`technical-design.md` §4 after Round 3, but the PRD's IA prose should match.

**Changes to PRD:**
- Savings & Investments nested items reduce to: **Overview, Goals, Portfolio** (holdings live
  inside Portfolio/overview, not a separate "Assets/Accounts" screen). Remove any "Accounts"
  and "Sleeves" sub-items.
- Taxes nested items reduce to: **Current tax year, Prep checklist, Tax archive**
  (already aligned). Confirm no "Estimated payments" or "Gains & income" leaf items remain.
- Add a one-line note: removed screens surface their content within a parent screen; nothing
  is dropped from v1 except goal status states.

---

### §7 Savings & Investments module

The review collapses several portfolio screens into a holdings-centric Portfolio overview and
removes goal status.

**Changes to PRD §7:**
- Remove "and status" from the savings-goal create/manage requirement. Goals have no
  active/archived state in v1 — every listed goal is assumed active; the user adds/removes as
  needed.
- Holdings table is the **primary** surface of the portfolio view; supporting tables are
  secondary.
- Add a **holdings table view toggle**: standard holdings table ⇄ heat map table (period
  performance per holding), replacing the dedicated benchmark screen.
- Sleeve table moves to the **bottom of the Portfolio overview**; remove any language implying
  a standalone sleeve screen.
- Benchmark/heat-map comparison requirements are retained but reframed as a *mode of the
  holdings table* rather than a separate view.

---

### §8 Tax module

The review removes the estimated-payments and gains & income *screens* but keeps their
functionality inside Current Tax Year, and re-focuses the prep checklist.

**Changes to PRD §8:**
- Keep all existing data requirements (realized gains/losses, dividend/interest income,
  estimated payments by quarter/year) — these now surface within the **Current Tax Year**
  view rather than as dedicated screens.
- Prep checklist becomes a **full-width, focal screen** with added educational content to
  help the user understand each tax-prep step. Remove other elements from that screen.
- The prep checklist is **not** shown on the Current Tax Year screen (it lives on its own
  screen only).

---

### Data model

**Changes to PRD:**
- Savings goal entity: remove the goal-status / lifecycle attribute from the v1 model (active
  and archived states deferred to V2). All other goal fields unchanged.
- No other entity changes — gains, income, payments, sleeves, and benchmarks all retain their
  entities; only their dedicated presentation surfaces change.

---

## Cascade

| Doc | Plan file | Why |
|---|---|---|
| `technical-design.md` | `update-technical-design-r2.md` | §4 sidebar, §8.5 goals status column, §16 S&I + Taxes UI requirements, §20 prototype order, §23 wireframes |
| `product-roadmap.md` | `update-product-roadmap-r2.md` | Phase 4 sleeve/benchmark/estimated-payments design tasks; Phase 5 module views; Out of scope list |
| `.specify/memory/constitution.md` | — | No principle changes; no amendment |

## Changelog stub (to append to product-requirements.md)

```
### Round 3 — 2026-06-12
Source: docs/_refinement/review-r2.md (second prototype review)

- Savings & Investments: holdings table is now the primary portfolio surface; benchmark heat
  map folded into a holdings table view toggle (dedicated benchmark screen removed)
- Sleeve table moved to bottom of Portfolio overview; dedicated sleeves screen deferred to V2
- Removed Accounts screen under Savings & Investments (duplicated Portfolio overview)
- Removed goal status (active/archived) from v1; all listed goals assumed active — deferred to V2
- Taxes: removed dedicated Estimated payments and Gains & income screens; functionality retained
  within Current Tax Year
- Prep checklist is now a full-width focal screen with educational content; removed from the
  Current Tax Year screen
```

## Prototype / design impact

Views to delete or alter in `prototype/` (flag for workflow step 6, not done in this plan):
- Delete: `savings-goals-active`, `savings-goals-archived`, `investments-sleeves`,
  `savings-accounts`, `investments-benchmark`, `taxes-estimated-payments`, `taxes-gains-income`
- Alter: `investments-holdings` (table-focal + heat-map toggle), `taxes-checklist`
  (full-width + educational), `taxes-current` (remove prep checklist block)

---

## Priority order for PRD edits

1. IA prose (Savings & Investments + Taxes nested items)
2. §7 Savings & Investments (holdings-focal, toggle, sleeve placement, goal status removed)
3. §8 Taxes (screen removals, prep checklist focus)
4. Scope lists (V2 additions)
5. Data model (goal status removal)
6. Changelog entry
