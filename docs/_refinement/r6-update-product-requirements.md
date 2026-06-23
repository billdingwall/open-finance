# Product Requirements Update Plan — Round 6

Source: `docs/_refinement/r6-review.md` (fourth prototype review — data structuring & information architecture)
Target: `docs/product-requirements.md`
Status: Proposed 2026-06-22

---

## Summary

Round 6 formalizes the **object model** the PRD has so far described loosely. The product-level impact
is concentrated in **§Data model** (canonical entities: rename terms, add Liability and Portfolio,
retire the "queued for a future round" footnote), **§5–§8** (each module's objects: accounts hold
assets *and* liabilities; Budget becomes a scoping container; Portfolio becomes the formal container
above sleeves; deductions become tax-adjustments with estimates and documents), and **§12** (object
management must handle multi-entry transactions).

> **Priority directive:** where r6-review conflicts with the current PRD or the r5
> `object-model-audit.md`, **r6-review wins.** The investment container is **Portfolio** (not the
> audit's "Strategy"); the account-group key is `account_group_id` (not `group_id`); group nesting is
> **not** adopted. No CSV-column detail belongs in the PRD — that lives in
> `r6-update-technical-design.md`; the PRD carries the conceptual model and user-facing behavior.

---

## Change index

| # | Section | Type | Impact |
|---|---|---|---|
| 1 | §Data model — canonical entities | Significant | Rename Theme/Entity→Account-group, Holding→Asset, Deduction→Tax-adjustment; add **Liability** and **Portfolio**; retire the "queued rename" footnote (now applied) |
| 2 | §5 Accounts module | Significant | Accounts contain **assets and liabilities**; introduce multi-entry transactions (transfers + paycheck splits) and the trade/credit transaction types |
| 3 | §6 Budget module | Minor | Budget is a named, scoped container of allocations (not an implicit "all personal transactions") |
| 4 | §7 Savings & Investments module | Significant | **Portfolio** is the formal container above sleeves; assets roll up Portfolio → Sleeve → Asset |
| 5 | §8 Tax module | Significant | Deductions → **Tax-adjustments**; add **Tax-estimate** (projection) and **Tax-document** (registry) concepts |
| 6 | §12 Object management | Minor | Add/edit/delete must support multi-entry transaction groups as a single unit |
| 7 | §Information architecture | Notation | No nav change; note that accounts surface both assets and liabilities |

---

## Detailed changes

### §Data model — Canonical file-based entities
Update the entity table and footnote:
- **Accounts**: `Theme/Entity` → **Account-group**; add **Liability** alongside Account/Asset.
- **Savings & Investments**: add **Portfolio** as the container above `PortfolioSleeve`; `Holding`/
  `Security`/`Position` consolidate under the **Asset** concept.
- **Taxes**: `DeductionRecord` → **Tax-adjustment**; add **Tax-estimate** and **Tax-document**.
- **Replace footnote [^group]:** it currently says the `entity_id`→`group_id` rename and Budget/
  Strategy work are "queued for a future object-model round." Round 6 **is** that round. Rewrite it to:
  the model-level rename is **applied in Round 6** as `entity_id`→`account_group_id` (plus
  `holding_id`→`asset_id`, `deduction_id`→`tax_adjustment_id`); the investment container is
  **Portfolio**; group nesting is **not** adopted. Point to `r6-update-technical-design.md`.

### §5 Accounts module
- State that an account is a container for **assets, liabilities, and transactions** — e.g. a brokerage
  account holds multiple assets; a mortgage account holds both an asset (the property) and a liability
  (the loan). Every account resolves to at least one asset, one liability, or both.
- Add **multi-entry transactions**: a transfer or a paycheck is one logical event spanning multiple
  rows linked by a shared group. Two shapes the module must support:
  - **Transfers / liability payments** net to zero across their entries.
  - **Paycheck (gross/net) splits** divide a gross amount into withholdings (HSA, insurance, federal/
    state tax) and net take-home; they do **not** net to zero. (This directly serves the §Accounts user
    story about a W-2 paycheck broken into HSA, insurance, 401k, taxes, and take-home.)
- Add the **trade** and **credit** transaction concepts: a `trade` swaps one asset for another (USD →
  AAPL, updating cost basis); a `credit` draws down a loan/line of credit. Investment buys/sells are
  part of this **single unified transaction history** — there is no separate investment ledger.

### §6 Budget module
- Reframe a **Budget** as a *named, scoped* plan — it declares which account-groups/accounts it
  monitors and contains category allocations — rather than an implicit "all personal transactions."
  This supports multiple budgets (e.g. household vs. a per-business budget), which §5 already implies.

### §7 Savings & Investments module
- Introduce **Portfolio** as the formal container: a portfolio groups sleeves and can track specific
  account-groups; assets belong to sleeves (Portfolio → Sleeve → Asset). This matches the §S&I user
  story about a core portfolio with multiple sleeves and smaller satellite portfolios.
- Note Portfolio supersedes the loose "sleeve-as-top-object" model; the free-text strategy moves onto
  the Portfolio.

### §8 Tax module
- Rename the deductions concept to **Tax-adjustment** (deductions, credits, and liabilities are kinds
  of adjustment). Keep the user-facing language of "deductions" where it reads naturally.
- Add **Tax-estimate**: a year's projected liability (estimated income/deductions, projected liability,
  safe-harbor target) — distinct from logged estimated payments.
- Add **Tax-document**: a registry of tax documents (W-2, 1099, receipts) linked to adjustments and a
  fiscal year. Adjustments can be sourced from paycheck withholding entries (§5 gross/net splits).

### §12 Object management (add / edit / delete)
- Extend the universal add/edit/delete requirement so a **multi-entry transaction group is created,
  edited, and deleted as a single unit** (a paycheck or split mortgage payment can't be entered one
  flat row at a time without breaking the group). Deletes still run the reference check from r5.

### §Information architecture
- No navigation change. Add a note that the Accounts surfaces show both **assets and liabilities** for
  an account (net-worth-relevant), and that Savings & Investments is organized by **Portfolio**.

---

## Items explicitly NOT changed
- **Group nesting** — not adopted (overrides r5-audit G1).
- **"Strategy" container name** — the PRD uses **Portfolio** (overrides r5-audit G3).
- **Navigation / screens** — unchanged from r5 (dashboard default, no filter bar, three tax screens).
- **Live market-data ingestion** for asset values — flagged by r6 as a *future* review item; not a v1
  requirement here.
- **Delete-on-reference default behavior** — still open.

## Changelog stub (to append to product-requirements.md)

```
### Round 6 — 2026-06-22
Source: docs/_refinement/r6-review.md (fourth prototype review — data structuring & IA);
update plan docs/_refinement/r6-update-product-requirements.md

- Data model: renamed Theme/Entity→Account-group, Holding→Asset, Deduction→Tax-adjustment; added
  Liability and Portfolio as first-class objects; retired the "rename queued" footnote (applied this
  round as entity_id→account_group_id, holding_id→asset_id, deduction_id→tax_adjustment_id)
- §5 Accounts: accounts contain assets and liabilities; added multi-entry transactions (transfers and
  gross/net paycheck splits) and the trade/credit transaction types
- §6 Budget: a budget is a named, scoped plan with category allocations (supports multiple budgets)
- §7 Savings & Investments: Portfolio is the formal container above sleeves (Portfolio → Sleeve → Asset)
- §8 Taxes: deductions → tax-adjustments; added tax-estimate (projection) and tax-document (registry)
- §12: multi-entry transaction groups are added/edited/deleted as a single unit
- Overrides the r5 object-model audit where they differ (Portfolio not Strategy, account_group_id not
  group_id, no group nesting) — r6-review takes priority
```
