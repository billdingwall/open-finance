# System Object Model — Gap Analysis & Proposed Properties

**Date**: 2026-06-15
**Round**: r5 — functional details
**Source**: `docs/_refinement/r5-review.md` → "Notes on system objects"
**Scope reviewed**:
- r5-review "Notes on system objects" (object descriptions + connection diagrams)
- `docs/product-requirements.md` §Data model, §5–§8
- `docs/technical-design.md` §8 (file specs), §10 (internal data model), §12 (engines)
- `prototype/data.js` (actual object shapes in use)

**Purpose**: This is the "initial audit of the object notes" the r5 review explicitly
deferred (`r5-review.md` line 120, TODO). It reconciles the r5 object vocabulary against
the existing canonical model, flags where they diverge, and proposes a concrete property
set for each r5 object so the next review can finalize how the parts connect.

> **Status**: Audit / proposal. This is a `_notes` working document, **not** an applied
> doc update. Nothing here changes the locked Phase-1 decisions until carried into
> `technical-design.md` via a proper `r5-update-*.md` plan.

---

## 1. The r5 object model, restated

r5 introduces a deliberately symmetric, connection-first vocabulary. Three object families,
each with a **container**, a **leaf**, and a **categorization** object, plus the shared
transaction/asset primitives:

| Family | Container | Leaf / unit | Categorization | Monitors |
|---|---|---|---|---|
| Accounts | **Account-group** | **Individual-account** | — | structure |
| Budget | **Budget** | (scopes groups/accounts) | **Budget-category** | transactions |
| Savings & Investments | **Strategy** | (scopes groups/accounts) | **Strategy-category** | assets |

Shared primitives owned by an individual-account:
- **Transaction** — money in/out/transfer
- **Asset** — a holding of wealth (cash, stocks, crypto…), editable directly

r5 connection diagrams (paraphrased):
```
Accounts:        Transaction → Asset  ⇒  Individual-account  ⇒  Account-group → Account-group
Budget:          Account-group / Transaction  ⇒  Budget ← Budget-category
Savings & Inv:   Account-group / Asset         ⇒  Strategy ← Strategy-category
```

The key insight is the **Budget ⇄ Strategy symmetry**: both are *scoping/monitoring*
objects layered over the same account-group substrate — Budget watches **transactions**,
Strategy watches **assets**. The existing docs do **not** model these two as parallel; they
are modeled as unrelated mechanisms. This is the single most important reconciliation below.

---

## 2. Terminology reconciliation

| r5 term | Existing doc term | File of record | Engine | Match? |
|---|---|---|---|---|
| Account-group | Theme / Entity | `Accounts/entities.csv` (§8.14) | AccountEngine | ⚠️ rename + new nesting |
| Individual-account | Account | `Accounts/accounts.csv` (§8.21) | AccountEngine | ✅ direct |
| Asset | Holding | `Investments/holdings.csv` (§8.8) | PortfolioEngine | ⚠️ scope broader than ticker holdings |
| Transaction | (Personal/Business)Transaction | `Accounts/transactions/YYYY-MM.csv` (§8.2) | AccountEngine | ✅ direct |
| Budget | PersonalBudget / BudgetPlan | `Budget/budgets.csv` (§8.4) | BudgetEngine | ❌ **no scoping object exists** |
| Budget-category | Category | `Budget/categories.csv` (§8.3) | BudgetEngine | ✅ direct |
| Strategy | (none — closest is Sleeve.strategy text) | — | PortfolioEngine | ❌ **no container object exists** |
| Strategy-category | Sleeve | `Investments/sleeves.csv` (§8.12) | PortfolioEngine | ⚠️ re-parents sleeve under strategy |

**Two outright missing objects** (Budget-as-scope, Strategy-as-container) and **three
shifted meanings** drive most of the findings.

The r5 "minor update #5" (rename *entity* → *group* in the UI) is consistent with the
Account-group rename here — adopt one vocabulary across UI and model.

---

## 3. Gap analysis findings

### G1 — "Account-group" requires a rename + a brand-new nesting capability  ·  **High**
r5: *"Account-group… connects multiple individual accounts into themes/entities. Account
groups act as the primary connecting objects,"* and the diagram shows **Account-group →
Account-group** (groups referencing groups).

- **Rename**: existing `entities.csv` / "theme/entity" → "Account-group" / "group". The
  prototype already half-mixes the terms (`entities` array, "Personal Assets" displayed as
  a theme). Aligns with minor-update #5.
- **Nesting (new)**: `entities.csv` (§8.14) is a **flat** list with no parent reference.
  r5's "Account-group → Account-group" implies a group can contain or reference another
  group (e.g. a "Businesses" parent over "Consulting LLC" + "Rental LLC"). **No column
  supports this today.** Either a `parent_group_id` self-reference or a documented decision
  that nesting is V2.
- **Recommendation**: rename in docs + UI; add optional `parent_group_id`; decide whether
  one-level nesting ships in MVP or is deferred. Flag to user.

### G2 — Budget is not modeled as a scoping object  ·  **High**
r5: *"Budget = a grouping of account-groups / individual-accounts used to monitor
transactions."* Existing `Budget/budgets.csv` (§8.4) is a flat list of
`period + category_id + planned_amount` rows. There is **no Budget entity** that names a
budget or declares *which accounts/groups it covers*. Today "the budget" is implicitly
"all personal transactions."

- This blocks the r5 idea of multiple scoped budgets (e.g. a personal budget vs. a
  per-business-entity budget — which the PRD §5 already gestures at with "entity-specific
  category definitions and monthly budget targets").
- **Recommendation**: introduce a `Budget/budgets-defs.csv` (or add a `budget_id` +
  `Budget/budget-scopes.csv`) defining each budget and the group/account IDs it monitors;
  re-key `budgets.csv` rows by `budget_id`. See proposed properties §4.5.

### G3 — Strategy (container) does not exist; Sleeve is the de-facto top object  ·  **High**
r5: *"Strategy = a grouping of account groups / individual accounts used to monitor
assets,"* with *"Strategy-categories = sleeves within a strategy."* Existing docs have
**Sleeve** as the top-level unit; `Sleeve.strategy` is just a free-text description. There
is no object that groups sleeves or scopes a strategy to accounts.

- This is the asset-side mirror of G2. r5 wants Strategy : Sleeve to parallel Budget :
  Budget-category.
- **Recommendation**: introduce `Investments/strategies.csv`; add `strategy_id` to
  `sleeves.csv` to re-parent sleeves under a strategy; add a strategy→group/account scope
  (parallel to G2). See §4.6–§4.7.

### G4 — "Asset" is broader than the ticker-centric Holding  ·  **Medium**
r5: *"Asset = a holding of wealth like cash, stocks, crypto, etc. It can be associated with
transactions but can also be edited directly."* `holdings.csv` (§8.8) is ticker-shaped
(`ticker`, `quantity`, `cost_basis`, `market_value`, `sleeve_id`). It models securities
cleanly but is awkward for **cash balances and non-ticker assets** — yet the prototype
already shoehorns cash in (`ticker: 'CASH', qty: 1, price: 62300`).

- r5 also asserts assets are **directly editable** (not only derived from trades), which
  matches §8.8 being a maintained snapshot, but the relationship "Asset associated with
  Transactions" is not expressed in the schema (no link from a holding to the trades/
  transactions that built it beyond `lot_id` on the trade side).
- **Recommendation**: confirm holdings.csv is the Asset file; add an `asset_kind` enum
  (`security`, `cash`, `crypto`, `other`) so non-ticker assets are first-class; document the
  Asset↔Transaction link direction. See §4.3.

### G5 — Individual-account "stores both transactions and assets" — verify the FK spine  ·  **Medium**
r5 places both Transaction and Asset **under** Individual-account. The canonical model
agrees in principle (`transactions.account_id` and `holdings.account_id` both → `accounts.csv`),
but the **prototype violates the locked unified-registry decision**: `data.js` keeps a
separate `investmentAccounts` array (`brokerage-main`, `ira-main`, …) distinct from the
`accounts` array, and `holdings.account` points at the former. Per TDD §21 (locked), there
is **one** registry `Accounts/accounts.csv`; investment accounts are rows in it.

- **Recommendation**: prototype fix — fold `investmentAccounts` into `accounts` (or make it
  a derived filter `account_group: investment`); ensure `holdings.account_id` references the
  master registry. This is a prototype/data correctness gap, not a doc gap.

### G6 — Strategy-category ≠ SleeveTarget; sleeve re-parenting changes keys  ·  **Medium**
r5 maps "Strategy-category" to **Sleeve**. The existing `sleeve-targets.csv` (§8.13) is a
*different* object (per-ticker target weights inside a sleeve). So the r5 hierarchy is:
Strategy → Sleeve (= "strategy-category") → SleeveTarget (per-ticker). Adding `strategy_id`
to sleeves is additive (non-breaking per §9), but the conceptual renaming should be
documented so "category" isn't confused between Budget-category and Strategy-category.

### G7 — Universal edit/delete implies referential-integrity rules  ·  **Medium**
r5 functional-update #6: *"Any object that can be added, should also be removable and
editable."* The TDD write flow (§13) covers generic writes but says nothing about **delete
semantics** when an object is referenced. Deleting an Account-group referenced by accounts,
or an account referenced by transactions/holdings, or a category referenced by transactions,
needs a defined behavior (block, cascade-warn, or reassign).

- **Recommendation**: add a "delete with reference check" rule to §13 / §15 (cross-file
  validation already lists "unknown … reference" — deletion is the write-side of that).
  Every object below gets a stable `*_id` (most already do) precisely so referencing rows
  survive renames; deletion must surface referencing rows in the write preview.

### G8 — No object owns "Transfer" as a relationship  ·  **Low**
r5 defines Transaction as *"a purchase, a sell or a transfer."* Transfers link **two**
accounts. §8.2 has `transfer_group` (optional) but no documented pairing/validation. With
account-groups now first-class, intra-group vs. cross-group transfers matter for net-income
math. Worth a property note (§4.4) and a future rule.

### G9 — Object lifecycle: `is_active` is inconsistent  ·  **Low**
`accounts.csv` and `entities.csv` have `is_active`; goals explicitly **dropped** status
(V2, §8.5); categories have `is_active`. r5's "removable" objects + this inconsistency
suggest documenting one convention: soft-deactivate (`is_active=false`, retained for history)
vs. hard-delete (row removed). Recommend soft-deactivate for anything referenced by
historical transactions, hard-delete only for unreferenced rows.

---

## 4. Proposed object properties

For each r5 object: file of record, a property table (✅ exists today / 🆕 proposed new /
🔁 renamed), and the **connection keys** (foreign keys) that wire it to the rest of the
system. Types follow the §8 conventions.

### 4.1 Account-group  *(was Theme/Entity — `Accounts/entities.csv`)*

| Property | Type | Status | Notes |
|---|---|---|---|
| group_id | string | 🔁 was `entity_id` | Stable key referenced by accounts, budgets, strategies |
| display_name | string | ✅ | User-visible name |
| legal_name | string | ✅ | Optional (business groups) |
| group_type | enum | 🔁 was `entity_type` | `personal`, `employment`, `business`, `custom` |
| parent_group_id | string | 🆕 | **G1** — optional self-reference for group nesting; null = top-level |
| tax_id_hint | string | ✅ | EIN / tax id (optional) |
| sort_order | integer | 🆕 | Sidebar/card ordering (prototype implies a fixed order) |
| is_active | boolean | ✅ | Soft-deactivate flag (**G9**) |

**Connects to**: `parent_group_id → group_id` (self); referenced by `Account.group_id`,
`Budget.scope_group_ids`, `Strategy.scope_group_ids`, `Category.group_id`.

### 4.2 Individual-account  *(Account — `Accounts/accounts.csv`)*
Largely already specified (§8.21). Proposed additions in **bold-new**.

| Property | Type | Status | Notes |
|---|---|---|---|
| account_id | string | ✅ | Master key referenced everywhere |
| display_name | string | ✅ | |
| institution | string | ✅ | |
| account_group | enum | ✅ | employment, business, credit_card, investment, savings, checking, loan |
| account_type | string | ✅ | roth_ira, hysa, mortgage… |
| group_id | string | 🔁 was `entity_id` | Required — links to Account-group |
| is_active | boolean | ✅ | |
| tax_relevant | boolean | ✅ | |
| tax_treatment | string | ✅ | investment accounts only |
| performance_tracking | boolean | ✅ | investment accounts only |
| current_balance | decimal | 🆕 | Snapshot balance for the individual-account screen (**r5 functional #5**); for non-investment accounts where no holdings exist |
| notes | string | ✅ | |

**Connects to**: `group_id → Account-group`; owns `Transaction.account_id` and
`Asset.account_id`; referenced by `Budget`/`Strategy` scopes, deductions, goals
(`source_account_id`).

### 4.3 Asset  *(Holding — `Investments/holdings.csv`)*

| Property | Type | Status | Notes |
|---|---|---|---|
| holding_id | string | ✅ | (consider alias `asset_id`) |
| account_id | string | ✅ | → Individual-account (**G5** FK spine) |
| asset_kind | enum | 🆕 | **G4** — `security`, `cash`, `crypto`, `other` |
| ticker | string | ✅ | Optional when `asset_kind != security` |
| name | string | 🆕 (in proto) | Human label (proto has it; promote to spec) |
| quantity | decimal | ✅ | |
| cost_basis | decimal | ✅ | |
| market_value | decimal | ✅ | |
| sleeve_id | string | ✅ | → Strategy-category (sleeve); optional |
| asset_class | enum | ✅ | |
| sector | string | ✅ | |
| as_of_date | date | ✅ | Supports "edited directly" snapshot |

**Connects to**: `account_id → Individual-account`; `sleeve_id → Sleeve(Strategy-category)`;
associated with Trades via `lot_id`/`ticker` and (proposed) the account's transactions.

### 4.4 Transaction  *(`Accounts/transactions/YYYY-MM.csv`)*
Already well-specified (§8.2). Only connection-related notes:

| Property | Type | Status | Notes |
|---|---|---|---|
| transaction_id | string | ✅ | Stable across recategorization |
| account_id | string | ✅ | → Individual-account |
| category_id | string | ✅ | → Budget-category |
| amount / direction | decimal/enum | ✅ | Locked sign convention |
| transfer_group | string | ✅ | **G8** — pairs the two legs of a transfer; recommend a future validation that a transfer_group resolves to ≥2 rows across accounts |
| savings_goal_id | string | ✅ | → SavingsGoal |
| deductible | boolean | ✅ | → Tax module |

**Connects to**: `account_id`, `category_id`, `savings_goal_id`, `transfer_group`.
(Asset linkage for investment buys/sells is carried by `Investments/transactions.csv` Trades,
not this personal/business file — worth stating explicitly so reviewers don't expect ticker
data here.)

### 4.5 Budget  *(NEW scoping object — proposed `Budget/budgets-defs.csv`)*  ·  **G2**

| Property | Type | Status | Notes |
|---|---|---|---|
| budget_id | string | 🆕 | Stable key |
| name | string | 🆕 | e.g. "Household", "Consulting LLC" |
| scope_group_ids | string[] | 🆕 | Account-groups this budget monitors |
| scope_account_ids | string[] | 🆕 | Optional individual-account overrides/additions |
| period_kind | enum | 🆕 | `monthly` (v1) |
| is_active | boolean | 🆕 | |

The existing `Budget/budgets.csv` (period/category/planned) becomes the **lines** of a
budget; add `budget_id` to it so lines belong to a budget. If only one budget ships in MVP,
a single seeded default `budget_id` keeps this backward-compatible.

**Connects to**: `scope_group_ids → Account-group`, `scope_account_ids → Account`;
parent of `budgets.csv` lines; lines reference `Budget-category`. Monitors Transactions via
the scoped accounts.

### 4.6 Budget-category  *(Category — `Budget/categories.csv`)*
Already specified (§8.3). Connection-relevant columns: `category_id` (→ referenced by
Transactions and budget lines), `group_id` (category grouping, distinct from Account-group —
**naming collision to resolve**: rename this to `category_group_id` to avoid confusion with
the new Account-group `group_id`). `entity_id` → rename `group_id` to point at Account-group.
`tax_group` → Tax module.

> **Naming hazard**: "group" now means three things — Account-group, `account_group` enum on
> an account, and the category `group_id`. Recommend: Account-group=`group_id`,
> account classification=`account_group` (enum, keep), category grouping=`category_group_id`.

### 4.7 Strategy  *(NEW container — proposed `Investments/strategies.csv`)*  ·  **G3**

| Property | Type | Status | Notes |
|---|---|---|---|
| strategy_id | string | 🆕 | |
| name | string | 🆕 | e.g. "Long-term Growth" |
| description | string | 🆕 | The text currently stuffed in `Sleeve.strategy` |
| scope_group_ids | string[] | 🆕 | Account-groups monitored (mirror of Budget) |
| scope_account_ids | string[] | 🆕 | Optional |
| benchmark_id | string | 🆕 | Default benchmark for the strategy |
| is_active | boolean | 🆕 | |

**Connects to**: `scope_group_ids → Account-group`; parent of Sleeves via `Sleeve.strategy_id`;
monitors Assets via the scoped accounts.

### 4.8 Strategy-category  *(Sleeve — `Investments/sleeves.csv`)*  ·  **G6**

| Property | Type | Status | Notes |
|---|---|---|---|
| sleeve_id | string | ✅ | |
| strategy_id | string | 🆕 | → Strategy (re-parents sleeve; null-safe for backward compat) |
| name | string | ✅ | |
| strategy (text) | string | 🔁 | Move free-text to `Strategy.description`; keep or drop |
| monthly_contribution_target | decimal | ✅ | |
| benchmark_id | string | ✅ | |

**Connects to**: `strategy_id → Strategy`; referenced by `Asset.sleeve_id` and
`SleeveTarget.sleeve_id`.

---

## 5. Consolidated connection map (proposed)

```
                         parent_group_id
                          ┌────────────┐
                          ▼            │
                    Account-group ─────┘        (groups can nest — G1)
                       ▲   ▲   ▲
        group_id ──────┘   │   └────── scope_group_ids
                           │              ▲        ▲
                 Individual-account       │        │
                    ▲          ▲          │        │
        account_id ─┘          └─ account_id       │
            │                       │              │
       Transaction               Asset            │
            │ category_id           │ sleeve_id    │
            ▼                       ▼              │
       Budget-category          Strategy-category  │
            ▲ (lines)               ▲ (sleeves)    │
            │ budget_id             │ strategy_id  │
          Budget ──────────────── Strategy ────────┘
        (monitors Transactions)  (monitors Assets)
```

Symmetry to lock: **Budget : Budget-category : Transaction**  ≡
**Strategy : Strategy-category(Sleeve) : Asset**, both scoped by Account-groups.

---

## 6. Open questions for the next review

1. **Group nesting** (G1): does one-level Account-group nesting ship in MVP, or is
   `parent_group_id` reserved for V2?
2. **Multiple budgets** (G2): one global budget in MVP, or per-group budgets from the start?
   (PRD §5 already implies per-business-entity budgets.)
3. **Strategy as a real object** (G3): introduce `Investments/strategies.csv` now, or keep
   Sleeve as the top object for MVP and treat Strategy as a UI grouping only?
4. **Asset kinds** (G4): does MVP need first-class cash/crypto assets, or stay ticker-only
   and represent cash as account balances?
5. **Delete semantics** (G7): block-on-reference vs. cascade-warn vs. reassign — pick the
   default behavior for the universal edit/delete requirement.
6. **"group" naming collision** (§4.6): confirm `group_id` (Account-group) /
   `account_group` (enum) / `category_group_id` (category grouping) split.

## 7. If accepted, docs to touch (for a future `r5-update-*.md`)

- `technical-design.md` §8.14 (rename entity→group, add `parent_group_id`), §8.3 (rename
  category `group_id`→`category_group_id`, `entity_id`→`group_id`), §8.4 (+`budget_id`),
  §8.8 (+`asset_kind`, +`name`), §8.12 (+`strategy_id`); **new** §8.x Budget defs and
  Strategies; §10 entity list (+Budget scope, +Strategy); §13/§15 (delete-with-reference rule).
- `product-requirements.md` §Data model (rename + add Budget/Strategy containers), §5
  (group nesting), §7 (Strategy object).
- `constitution.md` — only if "removable objects / referential integrity" rises to a
  principle (likely not; it's a write-flow rule).
- `prototype/` — **G5** fix: unify `investmentAccounts` into the master `accounts` registry.
