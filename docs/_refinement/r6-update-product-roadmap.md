# Product Roadmap Update Plan — Round 6

Source: `docs/_refinement/r6-review.md` (fourth prototype review — data structuring & information architecture)
Target: `docs/product-roadmap.md`
Status: Proposed 2026-06-22

---

## Summary

Round 6 is a schema/object-model round, so its roadmap impact lands earliest — in **Phase 1**
(models + schema registry must define the renamed files, four new files, and multi-entry columns) and
**Phase 2** (validation engine gains multi-entry group rules; the rename ships as a coordinated schema
migration). Downstream: **Phase 3** (AccountEngine derives liability balances; Budget becomes a scope),
**Phase 4** (PortfolioEngine gains the Portfolio container; TaxEngine moves to tax-adjustments +
estimates + documents), **Phase 5** (asset/liability surfaces, Portfolio views, a multi-entry
transaction editor), and **Phase 6** (atomic multi-entry group writes). Open Decisions gains the
reconciliation items and the reopened deductions-file decision.

> **Priority directive:** where r6-review conflicts with the current roadmap or the r5
> `object-model-audit.md`, **r6-review wins** — Portfolio (not "Strategy") container, `account_group_id`
> (not `group_id`), and **no** group nesting.

---

## Change index

| # | Section | Type | Impact |
|---|---|---|---|
| 1 | Phase 1 — Dev (models/schemas) | Significant | Define renamed files + 4 new files (liabilities, portfolios, tax estimates, tax documents) + multi-entry transaction columns |
| 2 | Phase 2 — Dev (validation + migration) | Significant | Multi-entry group validation rules; one-time rename/new-file **schema migration** with preview |
| 3 | Phase 3 — Dev (Accounts/Budget) | Minor | AccountEngine derives `Liability.principal_balance`; Budget modeled as a scope over allocations |
| 4 | Phase 4 — Dev (S&I/Tax) | Significant | PortfolioEngine gains the Portfolio container above sleeves; TaxEngine → tax-adjustments + tax-estimates + tax-documents |
| 5 | Phase 5 — Presentation | Significant | Account screens surface assets **and** liabilities; Portfolio views; **multi-entry transaction editor** |
| 6 | Phase 6 — Write flows | Minor | Multi-entry groups written atomically (no half-applied group) |
| 7 | Open Decisions | Minor | Record the reopened deductions-file decision; note r6 reconciliation items resolved; delete-on-reference still open |

---

## Detailed changes

### Phase 1 — Foundation & Architecture (Dev)
- Models and `SchemaRegistry` must define the **renamed** files (`account-groups.csv`/
  `account_group_id`, `assets.csv`/`asset_id`, `tax-adjustments.csv`/`tax_adjustment_id`) and the **new**
  files: `Accounts/liabilities.csv`, `Investments/portfolios.csv`, `Taxes/estimates.csv`,
  `Taxes/documents.csv`.
- Transaction model gains `type` (income/expense/transfer/trade/credit), `group_id`, `group_role`,
  `sending_asset_id`, `receiving_asset_id`, `liability_id`, `source_id`, `tags`.
- Add a Portfolio→Sleeve→Asset parentage (`portfolio_id` on sleeves) and the Budget→Budget-allocation
  split.

### Phase 2 — Parsing, Validation & Infrastructure (Dev)
- ValidationEngine: add **multi-entry group** rules — balanced groups (transfers) net to zero; gross/net
  groups satisfy `net = gross − Σ(withholding)`; `group_id` is a shared non-unique connector.
- Add a one-time, deterministic, **preview-able schema migration** (Safe-writes principle) that performs
  the three file/column renames atomically, seeds the four new files, **migrates
  `Investments/transactions.csv` rows into the unified monthly ledger as `trade`-type rows**
  (decision 5), and bumps `schema_version` / updates `manifest.json`. This is the concrete deliverable
  behind r6 Architectural recommendation #7.

### Phase 3 — Domain Layer I (Dev)
- AccountEngine derives `Liability.principal_balance` from the ledger (mirrors balance derivation);
  add a `LiabilityEngine` only if it earns its own surface.
- BudgetEngine treats a Budget as a named scope (account-group/account IDs) over its allocations.

### Phase 4 — Domain Layer II (Dev)
- PortfolioEngine gains the **Portfolio** container above sleeves (supersedes the loose sleeve-as-top
  model); the free-text strategy moves onto Portfolio.
- **Investment trades fold into the unified ledger** (decision 5): PortfolioEngine reads trades as
  `trade`-type rows from `Accounts/transactions/YYYY-MM.csv`; `Investments/transactions.csv` is
  deprecated. This is a **larger refactor** of the investment ingestion path — budget Phase-4 time for it.
- TaxEngine/TaxPrepEngine move from deductions to **tax-adjustments**, add **tax-estimate** projections
  and a **tax-document** registry; adjustments can be generated from paycheck withholding entries.

### Phase 5 — Presentation (Design + Dev)
- Account-group and per-account screens surface **assets and liabilities** (net-worth view).
- Savings & Investments is organized by **Portfolio**; add Portfolio views above the sleeve table.
- Add a **multi-entry transaction editor** (Design + Dev): a paycheck (gross → withholdings → net) or a
  split mortgage payment (principal/interest) is entered as one grouped unit, not flat rows.

### Phase 6 — Write Flows, Repair & Export (Dev)
- Multi-entry groups are written as a single atomic unit through the existing safe-write machinery;
  group validation (Phase 2) runs in the write preview.

### Open Decisions (Pre-Build)
- Record that the **deductions-file decision was reopened** (`deductions.csv`/`deduction_type` →
  `tax-adjustments.csv`/`adjustment_type`) — now resolved per r6.
- The r6 reconciliation items are **resolved** (settled 2026-06-23) and folded into the plans: kept
  two-tier `account_group` + `account_type`; `status` canonical; categories add `parent_category_id` +
  `category_group_id`; assets add `security_class`; trades fold into the unified ledger;
  `adjustment_type` = union enum.
- **Default delete-on-reference behavior** remains **open** (r6 only mandates surfacing references).

---

## Items explicitly NOT changed
- Phase order and milestone gates — unchanged.
- **Group nesting** — not added (overrides r5-audit G1).
- **"Strategy" container** — the roadmap uses **Portfolio** (overrides r5-audit G3).
- Live market-data ingestion for asset values — future review, not scheduled into v1 here.

## Changelog stub (to append to product-roadmap.md)

```
### Round 6 — 2026-06-22
Source: docs/_refinement/r6-review.md (fourth prototype review — data structuring & IA);
update plan docs/_refinement/r6-update-product-roadmap.md

- Phase 1: schema/models define the three renamed files + four new files (liabilities, portfolios,
  tax estimates, tax documents) and the multi-entry transaction columns
- Phase 2: added multi-entry group validation; added a one-time preview-able schema migration for the
  renames + new files
- Phase 3: AccountEngine derives liability balances; Budget modeled as a scope over allocations
- Phase 4: PortfolioEngine gains the Portfolio container; investment trades fold into the unified
  ledger (Investments/transactions.csv deprecated); TaxEngine → tax-adjustments + tax-estimates +
  tax-documents
- Phase 5: account screens surface assets and liabilities; Portfolio views; new multi-entry transaction
  editor
- Phase 6: multi-entry groups written atomically
- Open Decisions: recorded the reopened deductions-file decision; r6 reconciliation items resolved
  (settled 2026-06-23); delete-on-reference behavior still open
- Overrides the r5 object-model audit where they differ (Portfolio not Strategy, account_group_id not
  group_id, no group nesting) — r6-review takes priority
```
