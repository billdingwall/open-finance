# Technical Design Update Plan — Round 4

Source: `docs/product-requirements.md` (post Round 4 / r4-review.md updates), `docs/_refinement/r4-review.md`
Target: `docs/technical-design.md`
Status: Proposed 2026-06-12

---

## Summary

Round 4 trims screens. Because the Round 3 sidebar refinement (2026-06-10) already removed
most of these items from §4 navigation, several changes here are confirmations rather than
edits. The substantive technical work is in §8.5 (drop goal status), §16 (collapse the
portfolio screens into a holdings-focal Portfolio overview, re-focus the prep checklist),
§20 (prototype order), and §23 (wireframe flags).

No CSV files are deleted. Sleeves (`8.12`/`8.13`), the benchmark series (`8.11`), estimated
payments (`8.19`), and the gains/income source data all keep their file specs — only their
presentation surfaces change. The single schema change is removing the `status` column from
`Savings/goals.csv`.

---

## Change index

| # | Section | Type | Impact |
|---|---|---|---|
| 1 | §4 Information architecture | Confirm / minor | S&I sidebar items; confirm Taxes already trimmed |
| 2 | §8.5 Savings goals CSV | Schema change | Remove `status` enum column |
| 3 | §16 UI requirements | Significant | Collapse Assets/Portfolio into holdings-focal Portfolio; heat-map toggle; Taxes screen merges; prep checklist focus |
| 4 | §20 Rapid prototype order | Minor | Fold removed screens into parent steps |
| 5 | §23 Wireframes | Notation | Flag removed/changed screens |

---

## Detailed changes

### §4 Information architecture

**Sidebar — Savings & Investments.** Current items: Overview, Goals, Assets, Portfolio.
- Remove **Assets** as a distinct nav item — holdings live inside the Portfolio overview
  (the review found Assets/Accounts duplicated Portfolio overview).
- Keep **Portfolio** as the overview screen; the sleeve table is appended to its bottom
  (option (a) per review author). No separate "Sleeves" item (already absent post Round 3).
- Resulting items: **Overview, Goals, Portfolio**.

**Sidebar — Taxes.** Current items: Current tax year, Prep checklist, Tax archive —
**(already aligned)** after Round 3. Confirm no Estimated payments / Gains & income leaf items
remain.

---

### §8.5 Savings goals CSV — schema change

Remove the `status` column. The active/archived lifecycle is deferred to V2; every goal in the
file is treated as active in v1.

**Current required columns** include `status | enum`.

**Proposed:** drop `status`. Add a note:

> Goal lifecycle states (active/archived) are V2. In v1 every row in `goals.csv` is an active
> goal; the user adds and removes rows directly. No `status` column is read or written.

Downstream check: §15 validation rules and any §10 entity reference to goal status must drop
the field. `SavingsGoalEngine` (§12) should not branch on status.

---

### §16 UI requirements

#### Savings & Investments (restructure)

Collapse the **Assets** and **Portfolio** subsections into a single holdings-focal Portfolio
overview. Goals subsection unchanged except goal-status removal.

**Goals** must show (unchanged): goal cards, monthly funding status, goal-to-budget links,
linked transactions/notes. Remove any active/archived grouping.

**Portfolio** (replaces both "Assets" and the old "Portfolio" sleeve subsection) must show:
- Holdings table as the **primary** surface (account-level and aggregate)
- **Holdings table view toggle**: standard holdings table ⇄ heat map table showing % growth
  per period (D, W, M, 3M, 6M, 1Y, 3Y, 5Y) per holding — this replaces the dedicated benchmark
  view
- S&P 500 % growth comparison per account (Brokerage, Savings, IRA) and sector performance
  weighted against S&P 500, presented within the heat-map mode
- Account allocation view
- Tax-lot drill-down
- **Sleeve table appended at the bottom**: sleeve list with strategy, monthly contribution
  target, target vs actual weights, drift indicator, linked strategy note

Remove the standalone **Assets** heading and the standalone **Portfolio (sleeve-only)** heading.

#### Taxes (screen merges + prep checklist focus)

**Current tax year** must show (retain all functionality, now consolidated here):
- YTD taxable income, taxes paid vs owed, effective rate per account
- Estimated payment schedule by quarter and year (no separate Estimated payments screen)
- Realized gain/loss summary and income summary — dividends, interest (no separate Gains &
  Income screen)
- Deductions view: standard vs itemized, above-the-line, Schedule C linked to business entities
- Taxable income minus deductibles projection
- Business tax-prep summary
- **Must NOT show the prep checklist** (it lives on its own screen)

**Prep checklist** must show:
- The prep checklist as the **full-width, focal** content of the screen
- Educational content explaining each tax-prep step to the user
- Complete / incomplete / missing-input states with source links
- No other competing elements on the screen

**Tax archive** — unchanged.

---

### §20 Rapid prototype order

No reordering of phases. Update wording so removed screens are listed as folded into their
parent step (e.g. benchmark heat map is part of the holdings/portfolio step; estimated payments
and gains/income are part of the tax module step; goals step has no status states).

---

### §23 Wireframes

Flag the following until new wireframes are produced:

| Wireframe | Issue |
|---|---|
| Savings Goals | Active/archived states removed; goals are a flat list |
| Investments | Holdings table is now primary; benchmark folded into a holdings toggle; sleeve table moves to bottom of Portfolio overview |
| Taxes | Estimated payments and Gains & income merged into Current tax year; prep checklist is its own full-width screen |

New/updated wireframes needed (not yet produced):
- `portfolio-overview.svg` — holdings-focal Portfolio with table/heat-map toggle and sleeve table
- `taxes-current-year.svg` — consolidated Current Tax Year (payments + gains/income inline)
- `taxes-prep-checklist.svg` — full-width prep checklist with educational content

---

## Items explicitly NOT changed

- §8.11 S&P 500 benchmark CSV — retained (feeds the heat-map toggle)
- §8.12 / §8.13 Sleeves + sleeve targets CSV — retained (feed the sleeve table)
- §8.19 Estimated payments CSV — retained (feeds Current Tax Year)
- §10 entities for gains, dividends, payments, sleeves, benchmarks — retained
- §21 locked decisions — no reopening required

## Changelog stub (to append to technical-design.md)

```
### Round 4 — 2026-06-12
Source: docs/_refinement/r4-review.md (second prototype review)

- §4: Savings & Investments sidebar reduced to Overview, Goals, Portfolio (Assets removed —
  holdings live inside Portfolio overview); confirmed Taxes sidebar already trimmed
- §8.5: Removed `status` column from Savings/goals.csv; goal active/archived states deferred to V2
- §16: Restructured Savings & Investments — holdings table is the primary Portfolio surface;
  benchmark heat map is now a holdings table view toggle; sleeve table appended to Portfolio
  overview bottom; removed standalone Assets and sleeve-only Portfolio subsections
- §16: Taxes — folded Estimated payments and Gains & income into Current tax year; prep checklist
  is a full-width focal screen with educational content and is removed from Current tax year
- §20: Reworded prototype order to fold removed screens into parent steps
- §23: Flagged Savings Goals, Investments, and Taxes wireframes as outdated; listed three new
  wireframes needed
- No CSV file specs removed (sleeves, benchmark, estimated payments retained)
```
