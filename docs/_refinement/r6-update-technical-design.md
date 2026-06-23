# Technical Design Update Plan — Round 6

Source: `docs/_refinement/r6-review.md` (fourth prototype review — data structuring & information architecture)
Target: `docs/technical-design.md`
Status: Proposed 2026-06-22

---

## Summary

Round 6 is the **object-model / schema round** that Round 5 explicitly deferred (see
`docs/_notes/object-model-audit.md`). Unlike r5 (UI-only, *no CSV specs changed*), **r6 changes the
file specifications**: three file/column renames, four new files, and column additions across the
ledger, accounts, categories, budgets, sleeves, and tax files. It also formalizes a first-class
**Liability** object, a **Portfolio** container, and **multi-entry transactions**.

> **Priority directive (from the user):** where r6-review conflicts with the current docs *or* with
> the earlier r5 `object-model-audit.md`, **r6-review wins.** This plan therefore overrides several
> r5-audit proposals — they are called out under "Overrides of the r5 object-model audit" below so the
> divergence is intentional and traceable.

This plan **reopens one locked §21 decision** (the deductions file structure) and **adds new locked
decisions**. Per `CLAUDE.md`, §21 must be updated in the same commit as the spec changes.

### Overrides of the r5 object-model audit
| r5-audit proposal | r6 decision (takes priority) |
|---|---|
| Account-group key `group_id` | **`account_group_id`** (full form; avoids colliding with the new `Transaction.group_id` multi-entry connector) |
| Investment container named **Strategy** (`strategies.csv`, `strategy_id`) | **Portfolio** (`portfolios.csv`, `portfolio_id`); sleeves re-parent under `portfolio_id` |
| Asset kind via `asset_kind` enum (security/cash/crypto/other) | **`asset_class`** enum (cash/equity/crypto/real-estate) on the renamed `assets.csv` |
| `parent_group_id` group nesting (G1) | **Not included** — r6 does not model group nesting; it stays deferred/V2 |
| Keep `Taxes/deductions.csv` / `deduction_type` | **Rename** to `tax-adjustments.csv` / `adjustment_type` (Tax-adjustment object) |
| Liability folded into account columns | **First-class Liability object** + new `Accounts/liabilities.csv` |

---

## Change index

| # | Section | Type | Impact |
|---|---|---|---|
| 1 | §6 Folder structure | Significant | Rename `entities.csv`→`account-groups.csv`, `holdings.csv`→`assets.csv`, `deductions.csv`→`tax-adjustments.csv`; add `liabilities.csv`, `portfolios.csv`, `estimates.csv`, `documents.csv` |
| 2 | §8.2 Transactions | Significant | +`type`, +`group_role`, generalize `transfer_group`→`group_id`, +`sending_asset_id`/`receiving_asset_id`/`liability_id`, +`source_id`, +`tags` |
| 3 | §8.3 Categories | Minor | `entity_id`→`account_group_id`; +`sort_order`; reconcile existing `group_id` with `parent_category_id` |
| 4 | §8.4 Budgets | Significant | Split into a **Budget** definition + **Budget-allocation** lines (`budget_id`, `allocation_id`, `type`, `planned_amount`→`amount`, `rollover_policy`→`rollover_amount`) |
| 5 | §8.8 Holdings → Assets | Significant | Rename file `assets.csv`, `holding_id`→`asset_id`, `market_value`→`current_value`; redefine `asset_class` (broad kind); +`name` |
| 6 | §8.9 Investment transactions | Significant | Fold securities trades into the unified ledger; deprecate `Investments/transactions.csv` (decision 5) |
| 7 | §8.12 Sleeves | Significant | +`portfolio_id` FK, +`goal`, +`target_allocation_percentage`; free-text `strategy` migrates to Portfolio |
| 8 | §8.14 Entities → Account-groups | Significant | Rename file `account-groups.csv`, `entity_id`→`account_group_id`, `entity_type`→`group_type`; +`description` |
| 9 | §8.21 Accounts | Significant | `entity_id`→`account_group_id`; +`status` enum (reconcile with `is_active`); +`current_balance`/`available_balance` (derived); reconcile `account_group`+`account_type` vs r6 single `account_type` |
| 10 | §8.23 Deductions → Tax-adjustments | Significant | Rename file/keys; `deduction_type`→`adjustment_type` (merge enums); +FK links + `receipt_path` |
| 11 | §8.x **New** Liabilities | New | `Accounts/liabilities.csv` — first-class Liability object |
| 12 | §8.x **New** Portfolios | New | `Investments/portfolios.csv` — Portfolio container above sleeves |
| 13 | §8.x **New** Tax estimates & documents | New | `Taxes/estimates.csv` (projection), `Taxes/documents.csv` (doc registry) |
| 14 | §9 Schema migration | Significant | Renames are breaking → version bump + migration runner for all renames/new files |
| 15 | §10 Internal data model | Significant | Add Liability, Portfolio; rename entity list terms; Budget-as-scope; Tax-adjustment |
| 16 | §12 Engines | Minor | Liability handling (extend AccountEngine); PortfolioEngine gains the Portfolio container; multi-entry write handling |
| 17 | §13 / §15 | Significant | Multi-entry group write + validation (net-to-zero transfers; gross=net+withholdings) |
| 18 | §21 Locked decisions | Significant | **Reopen** deductions-file decision; **add** liability-object, portfolio-container, multi-entry, and rename decisions |

---

## Detailed changes

### §6 Folder structure
Apply the three renames and add the four new files:
```
Accounts/
  accounts.csv
  account-groups.csv        # was entities.csv
  liabilities.csv           # NEW (= Liability)
  account-rules.csv
  transactions/YYYY-MM.csv
Investments/
  assets.csv                # was holdings.csv
  transactions.csv
  prices.csv
  portfolios.csv            # NEW (= Portfolio)
  sleeves.csv               # + portfolio_id
  sleeve-targets.csv
Taxes/
  tax-adjustments.csv       # was deductions.csv
  estimates.csv             # NEW (= Tax-estimate)
  documents.csv             # NEW (= Tax-document)
  settings.csv, estimated-payments.csv, archive/, yearly/
```

### §8.2 Unified transactions CSV
Add/extend columns (keep all existing columns — `merchant`, `direction`, `amount`, `category_id`,
`subcategory_id`, `savings_goal_id`, `deductible`, `notes`, provenance):

| Column | Type | Notes |
|---|---|---|
| type | enum | **NEW** — `income, expense, transfer, trade, credit` (classification per r6 Rulesets §1) |
| group_id | string | **Generalize** `transfer_group` → `group_id` — shared across multi-entry rows (transfers *and* gross/net splits) |
| group_role | enum | **NEW** — `leg, gross, net, withholding` |
| sending_asset_id | string | **NEW** — optional FK → `assets.csv` |
| receiving_asset_id | string | **NEW** — optional FK → `assets.csv` |
| liability_id | string | **NEW** — optional FK → `liabilities.csv` |
| source_id | string | **NEW** — optional normalized issuer (Transaction-source); the raw `merchant` string stays for pre-normalization |
| tags | string | **NEW** — optional pipe-delimited tag list |

Add a behavior note that `transaction_id` stays unique per row; `group_id` is a shared connector,
**not** a primary key.

### §8.3 Unified categories CSV
- Rename `entity_id` → `account_group_id` (optional group scoping).
- Add `sort_order` (integer, optional).
- **Category hierarchy + grouping, both** (**decision 3**): add `parent_category_id` (self-reference
  for sub-categories, per r6) **and** rename the existing `group_id` → `category_group_id` (the flat
  grouping label). This adds true hierarchy *and* removes the three-way "group" name collision.

### §8.4 Unified budgets CSV → Budget + Budget-allocation
r6 makes **Budget** a scoping object and the budget rows its **allocations** (mirrors r5-audit G2,
but with r6's object names). Two shapes:

- **Budget** (new definition rows — `Budget/budgets.csv` becomes the defs file, or add
  `Budget/budgets-defs.csv`): `budget_id, name, timeframe (monthly|weekly|annual), start_date,
  end_date, account_group_ids[], account_ids[]`.
- **Budget-allocation** (the lines): `allocation_id, budget_id, category_id, type (spending|savings),
  amount (was planned_amount), rollover_amount (was rollover_policy), period`. Keep `priority`.

If only one budget ships in MVP, seed a single default `budget_id` so existing lines stay
backward-compatible.

### §8.8 Holdings CSV → §8.8 Assets CSV
- Rename path `Investments/assets.csv`; `holding_id` → `asset_id`; `market_value` → `current_value`.
- **Redefine `asset_class`** to r6's broad kind enum: `cash, equity, crypto, real-estate`.
- **Add `security_class`** (**decision 4**) for the finer security classification (equity/bond/REIT/
  ETF…) the old `asset_class` carried; `sector` is retained as-is.
- Add `name` (human label; the prototype already carries it).
- Keep `account_id, ticker (optional when asset_class≠equity), quantity, cost_basis, sleeve_id,
  sector, as_of_date`. Note `current_value` is **derived** from `prices.csv` × `quantity`, not authored.

### §8.9 Investment transactions CSV — fold into the unified ledger (decision 5)
**Trades fold into the unified ledger.** Securities buys/sells are recorded as `trade`-type rows in
`Accounts/transactions/YYYY-MM.csv`, and `Investments/transactions.csv` is **deprecated / absorbed**
(mark §8.9 "Reserved — absorbed into Unified Transactions," like §8.15–§8.17).
- Carry the trade-specific fields (`trade_type`, `quantity`, `price`, `fees`, `lot_id`, `ticker`,
  `sleeve_id`) onto the unified transaction row as optional columns, populated only for `type = trade`
  (alongside `sending_asset_id`/`receiving_asset_id`).
- PortfolioEngine reads trades from the unified ledger; the Phase-2 migration moves existing
  `Investments/transactions.csv` rows into the monthly ledger. **This is a larger refactor of the
  investment ingestion path** — see the roadmap plan, Phase 4.

### §8.12 Sleeves CSV
- Add `portfolio_id` (FK → `portfolios.csv`; null-safe for backward compatibility).
- Add `goal` (optional) and `target_allocation_percentage`.
- Migrate the free-text `strategy` column to `Portfolio.strategy`; keep or drop the sleeve column.
- Keep `monthly_contribution_target, benchmark_id, linked_note_id`.

### §8.14 Customizable entities/themes CSV → §8.14 Account-groups CSV
- Rename path `Accounts/account-groups.csv`; `entity_id` → `account_group_id`; `entity_type` →
  `group_type` (`personal, employment, business, custom`).
- Add `description` (optional) to match the r6 Account-group object.
- Keep `display_name, legal_name, tax_id_hint, is_active`.
- **Not added:** `parent_group_id` (group nesting) — r6 omits it; nesting stays deferred/V2.

### §8.21 Accounts registry CSV
- Rename FK `entity_id` → `account_group_id` (required).
- Add `status` enum (`draft, active, frozen, closed`) as the **canonical** lifecycle field
  (**decision 2**); `is_active` becomes derived (`status == active`) / deprecated.
- Add `current_balance`, `available_balance` (**derived** from the ledger; cached for display).
- **Keep the two-tier classification** (**decision 1**): retain `account_group` (enum) for the
  high-level UI grouping and `account_type` (string) for the specific type — names unchanged,
  accepting the near-collision between `account_group` and `account_group_id`. r6's single
  `account_type` enum maps onto the specific-type column; it does not replace `account_group`.
- Keep `institution, tax_relevant, tax_year_opened, tax_treatment, performance_tracking, notes`.

### §8.23 Tax deductions CSV → §8.23 Tax-adjustments CSV
- Rename path `Taxes/tax-adjustments.csv`; `deduction_id` → `tax_adjustment_id`; `deduction_name` →
  `name`; `entity_id` → `account_group_id`.
- `deduction_type` → `adjustment_type` (**decision 6**) with the **union** enum: `standard,
  above_the_line, itemized, business-expense, credit, liability` — keeping the established tax concepts
  (`above_the_line`; `business-expense` is the rename of `schedule_c`). Document the
  `schedule_c → business-expense` mapping in the migration.
- Add optional FK links: `transaction_id, category_id, asset_id, liability_id` (back r6's "applies to"
  references) and `receipt_path`.
- Keep `tax_year, account_id, estimated_amount, confirmed_amount, status, notes`.

### §8.x New — Liabilities CSV  ·  `Accounts/liabilities.csv`
| Column | Type | Notes |
|---|---|---|
| liability_id | string | primary key |
| account_id | string | FK → accounts.csv |
| name | string | |
| liability_type | enum | credit-card, loan, mortgage |
| principal_balance | decimal | **derived** from the ledger |
| interest_rate | decimal | |
| credit_limit | decimal | optional |
| minimum_payment | decimal | optional |
| due_date | date | optional |

### §8.x New — Portfolios CSV  ·  `Investments/portfolios.csv`
| Column | Type | Notes |
|---|---|---|
| portfolio_id | string | primary key |
| name | string | |
| description | string | optional |
| strategy | string | optional (the free text formerly on Sleeve) |
| goal | string | optional |
| timeframe | string | optional |
| type | enum | retirement, brokerage, crypto, savings |
| account_group_ids | string[] | optional — account-groups this portfolio tracks |

### §8.x New — Tax estimates & documents
- `Taxes/estimates.csv` (Tax-estimate, a projection — **distinct** from `estimated-payments.csv`):
  `estimate_id, fiscal_year, estimated_income, estimated_deductions, projected_liability,
  target_safe_harbor`.
- `Taxes/documents.csv` (Tax-document registry): `document_id, name, file_path, tax_year, type
  (income-form, deduction-receipt, prior-return, other)`.

### §9 Metadata model — schema migration
The three renames are **breaking** changes (rename = breaking per §9). Bump `schema_version` for the
affected files and ship a migration runner (one deterministic, preview-able script — see r6-review
Architectural recommendation #7) that renames files, headers, and FK columns atomically, creates the
four new files, and updates `manifest.json`. Adding optional columns to existing files is non-breaking.

### §10 Internal data model
- Add **Liability** and **Portfolio** to the canonical entity list; note Sleeve re-parents under
  Portfolio (`portfolio_id`).
- Rename Theme/Entity → Account-group; Holding → Asset; Deduction → Tax-adjustment in the entity list
  (and the §10 footnote that currently says the rename is "queued").
- Note Budget is now a scoping object (composes Budget-allocation lines); Budget ⇄ Portfolio are the
  parallel transaction-side / asset-side scopes.

### §12 Service responsibilities
- AccountEngine (or a new `LiabilityEngine`) derives `Liability.principal_balance` from the ledger,
  the same way account balances are derived.
- PortfolioEngine gains the Portfolio container above sleeves.
- The write path gains **multi-entry group** handling (write a group atomically).

### §13 / §15 — multi-entry write & validation
- §13 write flow: a multi-entry group is written as a single atomic unit (no half-applied group).
- §15 validation rules, add:
  - **Balanced group:** `SUM(amount) WHERE group_id = X` = 0 (transfers, liability payments).
  - **Gross/net group:** exactly one `gross` and one `net` row; `net = gross − Σ(withholding)`.
  - (Delete-with-reference-check already added in r5 §15 — unchanged.)

### §21 Decisions to lock before build
- **Reopen** "Deductions file structure: one `Taxes/deductions.csv` with `deduction_type`" → now
  `Taxes/tax-adjustments.csv` with `adjustment_type` (Tax-adjustment object). Record the supersession.
- **Add** locked decisions:
  - Liability is a first-class object with its own `Accounts/liabilities.csv` (peer to Asset).
  - Portfolio is the container above sleeves (`Investments/portfolios.csv`, `portfolio_id` FK on
    sleeves) — adopted instead of the r5-audit "Strategy" container.
  - Account-group / Asset / Tax-adjustment storage names are aligned to the object names
    (`account_group_id`, `asset_id`, `tax_adjustment_id`).
  - Multi-entry transactions use a shared `group_id` + `group_role`; `group_id` is not a primary key.
- **Unaffected (still locked):** master `accounts.csv` registry, Savings/Investments folder split,
  tax-year-close action, right-pane default-closed.

---

## Items explicitly NOT changed
- **Group nesting** (`parent_group_id`) — r6 does not model it; stays deferred/V2 (overrides r5-audit G1).
- **"Strategy" object name** — r6 uses **Portfolio**; do not introduce `strategies.csv`/`strategy_id`.
- **`asset_kind`** — superseded by r6's `asset_class` enum on `assets.csv`.
- **Default delete-on-reference behavior** (block/cascade-warn/reassign) — still **open** (roadmap Open
  Decisions / r5-audit G7); r6 only mandates surfacing inbound references, not the resolution.
- **Savings goals (§8.5/§8.6), prices (§8.10), benchmarks (§8.11), tax settings (§8.18), estimated
  payments (§8.19), archive (§8.24)** — unchanged this round.

## Resolved reconciliation decisions (settled 2026-06-23)
1. §8.21 — **Keep** the two-tier `account_group` (enum) + `account_type` (string); names unchanged,
   near-collision with `account_group_id` accepted.
2. §8.21 — `status` is the **canonical** lifecycle field; `is_active` derived/deprecated.
3. §8.3 — Add **both** `parent_category_id` (hierarchy) and `category_group_id` (renamed flat label).
4. §8.8 — Add a dedicated **`security_class`** column for finer security classes; `asset_class` stays broad.
5. §8.9 — **Fold trades into the unified ledger**; deprecate `Investments/transactions.csv`.
6. §8.23 — `adjustment_type` = **union** enum: `standard, above_the_line, itemized, business-expense,
   credit, liability` (`schedule_c` → `business-expense`).

## Changelog stub (to append to technical-design.md)

```
### Round 6 — 2026-06-22
Source: docs/_refinement/r6-review.md (fourth prototype review — data structuring & IA);
update plan docs/_refinement/r6-update-technical-design.md

- §6/§8: renamed entities.csv→account-groups.csv (entity_id→account_group_id, entity_type→group_type),
  holdings.csv→assets.csv (holding_id→asset_id, market_value→current_value, asset_class redefined),
  deductions.csv→tax-adjustments.csv (deduction_id→tax_adjustment_id, deduction_type→adjustment_type)
- §6/§8: added liabilities.csv (first-class Liability), portfolios.csv (Portfolio container),
  Taxes/estimates.csv (Tax-estimate) and Taxes/documents.csv (Tax-document)
- §8.2: transactions gained type, group_id (generalized from transfer_group), group_role,
  sending_asset_id/receiving_asset_id/liability_id, source_id, tags
- §8.4: budgets split into a Budget definition (scope) + Budget-allocation lines
- §8.12: sleeves re-parented under portfolios (portfolio_id), +goal/+target_allocation_percentage
- §8.21: accounts entity_id→account_group_id, +status lifecycle (is_active derived), +derived
  current/available balance; kept two-tier account_group + account_type
- §8.9: investment trades fold into the unified ledger as trade-type rows; Investments/transactions.csv
  deprecated (absorbed)
- §9: renames are breaking — schema_version bump + migration runner; new files seeded; Investments
  trades migrated into the monthly ledger
- §10/§12/§13/§15: data model + engines updated; multi-entry group write + validation rules added
- §21: reopened the deductions-file decision; added liability-object, portfolio-container,
  storage-name-alignment, and multi-entry decisions
- Overrides the r5 object-model audit where they differ (account_group_id not group_id, Portfolio not
  Strategy, asset_class not asset_kind, no group nesting) — r6-review takes priority
- Reconciliation decisions settled (2026-06-23): kept two-tier account_group + account_type; status
  canonical (is_active derived); categories add parent_category_id + category_group_id; assets add
  security_class; trades fold into the unified ledger (Investments/transactions.csv deprecated);
  adjustment_type = union (standard/above_the_line/itemized/business-expense/credit/liability)
```
