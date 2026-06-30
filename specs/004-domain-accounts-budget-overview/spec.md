# Feature Specification: Domain Layer I — Accounts, Budget & Overview

**Feature Branch**: `004-domain-accounts-budget-overview`
**Created**: 2026-06-30
**Status**: Draft
**Input**: User description: "Phase 3 — Domain Layer I: Accounts, Budget & Overview. Build the three foundational read-only domain engines plus cross-domain linking, fleshing out the Phase-1 projection-model stubs and finalizing seed data."

## Overview

Phase 1 (foundation) and Phase 2 (parsing + validation) turned the workspace's CSV/Markdown files
into typed, validated domain records. This feature builds the first layer that turns those records
into **projections** — the derived, regenerable read model the app will later present.

Three engines are in scope, plus the cross-domain linker that joins them:

- **AccountEngine** — the master account read model. Every other domain references `account_id` from
  `Accounts/accounts.csv`, so this engine is built first and exposes **read-only projections only**.
- **BudgetEngine** — plan-vs-actual budgeting, trailing averages, and the spend-mix breakdown.
- **LinkingEngine** + **OverviewEngine** — cross-domain links (budget → goal, investment → sleeve)
  and the composed Overview KPI cards + month-over-month panel.

This is an **engine/model spec**: it delivers domain logic, projection models, seed data, and the
developer CLIs that exercise them. It deliberately **excludes** all SwiftUI views and UI design
decisions (card layouts, charts, empty-state visuals) — those land with the Phase 5 presentation
spec, the same way Phase 2's design tasks were deferred.

> **Terminology — two distinct "account group" concepts** (per `containers-and-budgets.md §3.21`):
> the **`account_group`** *enum* on an account (checking / savings / investment / credit_card / loan /
> employment / business) is its high-level classification; the **account-group** *object*
> (`Accounts/account-groups.csv`, referenced by `account_group_id`, typed by `group_type` = personal /
> employment / business / custom) is the user-facing grouping/theme. This spec uses "account-group
> (object)" for the latter where ambiguity is possible.

## Clarifications

### Session 2026-06-30

- Q: What does "YTD" anchor to for YTD net income and YTD cash inflow? → A: The workspace's current
  tax year — Jan 1 of `tax_year` (from `Taxes/settings.csv`) through the latest month present.
- Q: How is `taxes_paid` (the subtracted term in net income) sourced per account/group? → A: From the
  ledger — explicit tax line items (`group_role = withholding` legs + standalone tax-payment rows)
  within the group's accounts (refined under analyze-A2 below). `Taxes/estimated-payments.csv` feeds
  the Phase-4 Tax module, not per-account net income (it carries no account/group link).
- Q: What defines the "current period" for monthly cash inflow and the no-transactions
  rule-projection? → A: The month of an **as-of date** that defaults to today but is injectable, so
  projections are deterministic under test.
- Q: How is the Overview Savings card composed in Phase 3? → A: From `AccountEngine` over
  `account_group = savings` accounts — balance = sum of derived `current_balance`; monthly
  contributions = current-month net inflow to those accounts.
- Q: What is "YTD cash inflow vs retained equity" (FR-001)? → A: **Retained equity** is taxable
  income recognized in the year that is **not** part of personal monthly inflow — income that stays in
  a non-personal account instead of flowing to personal spending (e.g. undistributed business income
  held in a business account; reinvested realized gains). Personal **cash inflow** is the income
  available for personal spending. All income is counted for taxes-owed; only cash inflow is personal
  spending. *Phase-3 scope*: `AccountEngine` computes **business** retained equity (it does not read
  `type = trade` rows per FR-009); investment/reinvested-gain retained equity composes in Phase 4
  (`PortfolioEngine`/`TaxEngine`).
- Q: What exactly counts as `taxes_paid`? → A: Explicit tax line items in the ledger that sum to taxes
  already paid YTD — the `group_role = withholding` legs of a paycheck group (so
  `gross − taxes_paid = net`), plus standalone tax-payment rows (a row in a tax-payment category).
  In Phase 3 the operative source is withholding legs; standalone tax-payment rows are included when a
  workspace defines such a category.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Accounts read model from real files (Priority: P1)

As the foundation every downstream module depends on, the system reads the master account registry,
liabilities, account rules, and the unified transaction ledger, and produces account-level and
account-group-level projections: per-account monthly cash inflow, YTD net income, derived balances,
business P&L, and projected cash flow for accounts that have no transactions in the current period.

**Why this priority**: `AccountEngine` owns the master registry that Budget, Overview, and every
Phase 4 engine validates `account_id` against. Per the locked build-order rule it must be complete
and stable before any other domain engine. On its own it delivers a verifiable Accounts read model.

**Independent Test**: Run the accounts projection CLI against a fixture workspace and confirm the
aggregate overview, per-group, and per-account projections compute correctly — balances reconcile to
the ledger, transfers are excluded from income/expense, and business P&L matches hand-calculated
figures — with no other engine present.

**Acceptance Scenarios**:

1. **Given** a fixture workspace with accounts across all groups and a 12-month ledger, **When** the
   accounts projection is built, **Then** each account reports a monthly cash inflow and a YTD net
   income computed as `gross_income − total_expenses − taxes_paid` with `type = transfer` rows
   excluded from both gross and expenses.
2. **Given** an account with a derivable balance, **When** the projection is built, **Then**
   `current_balance` and any `Liability.principal_balance` are derived from the ledger, not read from
   a stored column.
3. **Given** a business account-group, **When** the per-group projection is built, **Then** a monthly
   business P&L (net income per period) is produced for that group.
4. **Given** an account with an active account-rule or estimate and **no** transactions in the
   current period, **When** the projection is built, **Then** the engine projects expected cash flow
   for that account from the rule/estimate rather than reporting zero.
5. **Given** a multi-entry transaction group (paycheck gross/net split or a transfer), **When**
   projections are built, **Then** the group is resolved as a unit and does not double-count.
6. **Given** a workspace with more than one `group_type = employment` account-group, **When**
   projections are built, **Then** each employment group is projected independently and aggregates
   correctly across them.

---

### User Story 2 - Budget plan-vs-actual with trailing averages (Priority: P2)

The system computes monthly budget totals, per-category plan-vs-actual variance, a 3-month trailing
average per category, and the spend-mix percentages (fixed / discretionary / savings / investments
as a share of net monthly income), resolving each budget's scope over its allocation lines.

**Why this priority**: Budget is the primary personal-finance view and the first KPI card with live
data. It depends on `AccountEngine`'s ledger access but is otherwise independent.

**Independent Test**: Run the budget projection CLI against a fixture with categories, a budget,
allocation lines, and several months of transactions; confirm variance, trailing averages (including
the partial-average path), and spend-mix percentages against hand-calculated values.

**Acceptance Scenarios**:

1. **Given** a budget scoped to one or more account-groups with allocation lines for a period,
   **When** the budget projection is built, **Then** each category reports planned, actual, and
   variance for that period.
2. **Given** a category with at least 3 prior months of actuals, **When** the trailing average is
   computed, **Then** it returns the mean of the last 3 months flagged as full-confidence.
3. **Given** a category with only 1–2 months of actuals, **When** the trailing average is computed,
   **Then** it returns a partial average carrying a data-sufficiency indicator (e.g. "avg of 1 mo")
   and never returns zero or blank.
4. **Given** a period's transactions, **When** the spend-mix is computed, **Then** fixed,
   discretionary, savings, and investment totals are expressed as percentages of net monthly income.
5. **Given** transactions tagged with a `savings_goal_id`, **When** the budget projection is built,
   **Then** savings-goal contributions are surfaced as a first-class budget output linked to the
   originating goal.

---

### User Story 3 - Composed Overview dashboard data (Priority: P3)

The system composes the five Overview KPI cards and the month-over-month panel from the available
engines, links budget contributions to goals and investment contributions to sleeves, and aggregates
validation issues — degrading gracefully where a Phase 4 engine does not yet exist.

**Why this priority**: Overview is the cross-domain composition layer. It depends on AccountEngine
and BudgetEngine and proves the stub contract that lets later phases slot in without rework.

**Independent Test**: Run the overview projection CLI against a fixture; confirm Budget, Savings, and
Business cards carry live values, the Investments and Taxes cards return the typed
"data not available" state, the month-over-month panel shows the trailing 6 months skipping empty
months, and the issues list mirrors the validation engine's output.

**Acceptance Scenarios**:

1. **Given** AccountEngine and BudgetEngine projections, **When** the Overview cards are composed,
   **Then** the Budget, Savings, and Business cards report live values.
2. **Given** that the Portfolio and Tax engines do not exist in this phase, **When** the Overview
   cards are composed, **Then** the Investments and Taxes cards return a typed
   "data not available" state — not nil, not a zero value.
3. **Given** a ledger spanning several months with one or more gap months, **When** the
   month-over-month panel is built, **Then** it includes the trailing 6 months and skips months that
   have no data rather than emitting a zero entry.
4. **Given** transactions carrying `savings_goal_id` / sleeve references, **When** links are built,
   **Then** each contribution resolves to a goal-funding link and/or sleeve-funding link.
5. **Given** a workspace with validation issues, **When** the Overview is built, **Then** its issue
   list reflects the validation engine's grouped issues for surfacing in the issues table.

---

### User Story 4 - Realistic starter workspace (Priority: P2)

A newly bootstrapped workspace seeds a realistic starter set — the canonical account-type taxonomy,
an expanded default budget category set across the standard groups, and the existing six starter
accounts — so a first-run workspace produces meaningful projections immediately.

**Why this priority**: The engines are only demonstrable against representative data; the seed set is
what every new user starts from and what the fixture/QA flows build on. It rides alongside the engine
work rather than blocking it.

**Independent Test**: Bootstrap a fresh workspace, then run validate + the projection CLIs; confirm
the seeded categories and accounts parse cleanly, validate with no errors, and yield non-empty
budget and accounts projections.

**Acceptance Scenarios**:

1. **Given** a fresh bootstrap, **When** `Budget/categories.csv` is seeded, **Then** it contains the
   default category set across Income, Essentials, Lifestyle, Savings, Investments, and Transfers
   groups, each with the correct `default_budget_behavior` and `tax_relevant` flag.
2. **Given** a fresh bootstrap, **When** the accounts are seeded, **Then** each seed account uses an
   `account_type` from the canonical taxonomy for its `account_group`.
3. **Given** a freshly bootstrapped workspace, **When** validation runs, **Then** no errors are
   reported against the seeded files.

### Edge Cases

- **Empty / sparse workspace**: no transactions, no budget, or fewer than 3 months of history — every
  projection returns a well-formed empty/partial result (never a crash, nil, or misleading zero).
- **Unreferenced or dangling IDs**: a transaction referencing an unknown `account_id`, or an
  allocation referencing an unknown `category_id` — the engine surfaces it through the validation
  layer rather than silently dropping or inventing data.
- **Transfers and multi-entry groups**: internal transfers must never read as income or expense;
  paycheck gross/net splits must reconcile and not double-count.
- **Multiple employment groups**: two jobs (two `employment` groups) aggregate without collision.
- **Gap months**: a month with no transactions is skipped in the MoM panel, not zero-filled.
- **Stub-engine cards**: Overview must render a distinct typed state for Investments/Taxes, not zeroes.

## Requirements *(mandatory)*

### Functional Requirements

**AccountEngine (read-only projections)**

- **FR-001**: System MUST build an aggregate account overview across all accounts: per-account
  monthly cash inflow from the unified ledger, YTD net income, and a YTD split of **personal cash
  inflow** vs **retained equity**. "Monthly" means the month of an injectable **as-of date** (defaults
  to today); "YTD" means Jan 1 of the workspace's current `tax_year` (`Taxes/settings.csv`) through the
  as-of month. **Retained equity** = taxable YTD income that is not personal monthly inflow (income
  retained in a non-personal account rather than drawn for personal spending); in Phase 3 this is
  business-group income retained in business accounts (investment/reinvested-gain retained equity is
  Phase 4, since `AccountEngine` does not read `type = trade` rows). Personal cash inflow + retained
  equity together account for all (non-transfer) income, so taxes-owed can be viewed against personal
  spending.
- **FR-002**: System MUST group accounts by account-group (`personal`, `employment`, `business`,
  `custom`) and produce per-group detail projections, including a per-period business P&L
  (net income) for `business` groups.
- **FR-003**: System MUST produce per-account detail projections: monthly gross vs expenses/tax and
  the account's transactions in context.
- **FR-004**: System MUST derive account balances and `Liability.principal_balance` from the
  transaction ledger rather than trusting stored balance columns.
- **FR-005**: System MUST compute YTD net income as `gross_income − total_expenses − taxes_paid`
  (YTD anchored to the workspace `tax_year` per FR-001), excluding `type = transfer` rows from both
  gross and expenses, using the per-group term mapping: employment gross = positive income rows;
  business gross = revenue rows; checking gross = deposits with expenses = non-transfer debits;
  `taxes_paid` = the sum of explicit tax line items within the group's accounts — the
  `group_role = withholding` legs of paycheck groups (so `gross − taxes_paid = net`) plus standalone
  tax-payment rows (a row in a tax-payment category). `taxes_paid` is **ledger-derived only**;
  `Taxes/estimated-payments.csv` is not consumed here (it feeds the Phase-4 Tax module and carries no
  account/group link).
- **FR-006**: System MUST apply account rules and estimates to project expected cash flow for
  accounts that have no transactions in the current period (the as-of date's month per FR-001).
- **FR-007**: System MUST resolve multi-entry transaction groups as units (transfers net to zero;
  paycheck gross/net splits reconcile `net = gross − Σ(withholding)`) without double-counting.
- **FR-008**: System MUST aggregate correctly across multiple account-groups of the same
  `group_type`, including more than one `employment` group.
- **FR-009**: AccountEngine MUST expose **read-only** projection interfaces only and MUST NOT absorb
  Tax or Investment domain logic (locked architectural constraint).

**BudgetEngine**

- **FR-010**: System MUST compute monthly totals for income, fixed, discretionary, transfers,
  savings, and investments for a budget period.
- **FR-011**: System MUST compute per-category plan-vs-actual variance over the budget's allocation
  lines, resolving the budget's scope (account-groups and/or accounts).
- **FR-012**: System MUST compute a 3-month trailing average per category that returns both the value
  and the number of months it is based on, flagged as a partial average when fewer than 3 months of
  history exist; it MUST never return zero or blank for a sparse category.
- **FR-013**: System MUST compute spend-mix percentages — fixed, discretionary, savings, and
  investments as shares of net monthly income.
- **FR-014**: System MUST surface savings-goal contributions (transactions tagged with
  `savings_goal_id`) as a first-class budget output linked to the goal.

**LinkingEngine & OverviewEngine**

- **FR-015**: System MUST build goal-funding links (budget contributions → savings goals via
  `savings_goal_id`) and sleeve-funding links (investment contributions → sleeves) from parsed
  records.
- **FR-016**: System MUST compose the five Overview KPI cards (Budget, Savings, Investments,
  Business, Taxes).
- **FR-017**: In this phase the Budget, Savings, and Business cards MUST carry live values (Budget
  from BudgetEngine; Savings and Business from AccountEngine), and the Investments and Taxes cards
  MUST return a typed "data not available" state — never nil, never a placeholder zero. The Savings
  card is derived from `AccountEngine` over `account_group = savings` accounts: balance = sum of
  derived `current_balance`; monthly contributions = current-month net inflow to those accounts.
- **FR-018**: System MUST produce month-over-month panel data covering the trailing 6 months and
  skipping months with no data.
- **FR-019**: System MUST aggregate validation issues for the Overview issues list, mirroring the
  validation engine's grouped output.

**Seed data & taxonomy**

- **FR-020**: System MUST define and apply the canonical account-type taxonomy per account-group as
  the seed/validation reference, while keeping `account_type` a free string for forward
  compatibility: `checking` {personal, joint}; `savings` {hysa, standard, money_market};
  `investment` {taxable, roth_ira, traditional_ira, hsa, 401k, sep_ira}; `credit_card`
  {personal, business}; `loan` {mortgage, auto, personal, student}; `employment` {w2, 1099};
  `business` {sole_prop, llc, s_corp}.
- **FR-021**: System MUST seed an expanded default budget category set on bootstrap across the groups
  Income (salary, business_income — fixed, `tax_relevant`), Essentials (housing, groceries,
  utilities, transport, insurance), Lifestyle (dining, entertainment, shopping, travel —
  discretionary), Savings (emergency, goals — savings), Investments (retirement, brokerage —
  investment), and Transfers (transfer), with `tax_relevant` set on income and business/health
  categories.
- **FR-022**: A freshly bootstrapped workspace MUST validate with no errors and produce non-empty
  accounts and budget projections.

**Cross-cutting**

- **FR-023**: Every engine MUST consume the Phase-2 parsing output (typed domain records) and MUST
  degrade gracefully on empty, sparse, or partially-invalid inputs without crashing.
- **FR-024**: Each engine MUST be exercisable through a developer CLI that prints its projection
  summary against a workspace, consistent with the existing Phase 1/2 CLI pattern.
- **FR-025**: Projections MUST be pure derivations of the files (regenerable, no hidden state) and
  MUST NOT write to the workspace — this phase is read-only.

### Key Entities *(include if feature involves data)*

- **AccountProjection set** — aggregate overview, per-account detail, and per-account-group detail
  (incl. business P&L / `BusinessMonthlySummary`); derived balances and liability principal; the YTD
  personal-cash-inflow vs retained-equity split.
- **AccountSummaryCard** — per-account monthly inflow + YTD net income (existing stub, fleshed out).
- **BudgetVarianceRow / BudgetMonthProjection / BudgetOverviewProjection** — per-category plan vs
  actual, trailing average (value + months-available), spend-mix percentages.
- **TrailingAverage** — value plus the count of months it is based on and a partial-confidence flag.
- **GoalFundingLink / SleeveFundingLink** — cross-domain contribution links (existing stubs, populated).
- **OverviewSummaryCard** — the five KPI cards with a live-or-"data not available" state (existing stub).
- **MonthlySnapshot** — a month-over-month panel entry (existing stub, populated; gaps skipped).
- **Account-type taxonomy** — canonical `account_type` values per `account_group` (seed/validation).
- **Default category set** — seeded `Budget/categories.csv` rows across the six category groups.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Running the three projection CLIs against a 12-month fixture workspace produces
  complete, non-empty Accounts, Budget, and Overview projections with no crashes.
- **SC-002**: Every derived account balance and liability principal reconciles exactly to the sum of
  its ledger entries in the fixture.
- **SC-003**: YTD net income for every account in the fixture matches hand-calculated figures, with
  internal transfers contributing zero to both income and expenses.
- **SC-004**: For a category with fewer than 3 months of history, the trailing average reports a
  partial average with the correct months-available count and is never zero or blank.
- **SC-005**: The Overview's Investments and Taxes cards report the typed "data not available" state
  in 100% of Phase-3 runs (no zeroes, no nils), while Budget, Savings, and Business report values.
- **SC-006**: The month-over-month panel for a ledger with gap months contains exactly the trailing
  6 populated months and no zero-filled gap entries.
- **SC-007**: A freshly bootstrapped workspace validates with zero errors and its seeded categories
  cover all six category groups.
- **SC-008**: A workspace with two `employment` account-groups aggregates employment income across
  both with no double-counting or collision.
- **SC-009**: No engine writes to the workspace during projection (verified read-only).
- **SC-010**: For a fixture with undistributed business income, YTD personal cash inflow excludes that
  income while YTD retained equity includes it, and (personal cash inflow + retained equity) reconciles
  to total non-transfer income — matching hand-calculated figures.

## Assumptions

- Scope is **engines + projection models + seed data only**. The six Phase-3 UI design DECIDEs
  (Accounts overview, per-account detail, Budget overview, Budget history, Overview dashboard, empty
  states) are deferred to the Phase 5 presentation spec. No SwiftUI views are built here.
- The Savings and Business Overview cards are derived from `AccountEngine` — Savings from
  `account_group = savings` account balances + current-month inflow (FR-017); Business from
  business-group P&L. `SavingsGoalEngine` is Phase 4 and is not required for these cards in Phase 3.
- `PortfolioEngine` and `TaxEngine` do not exist in this phase; the Overview consumes them as the
  typed "data not available" stub contract already locked in `core-domain.md §3`.
- "Estimated rate" definitions for the Savings and Investments KPI cards are Phase 4 product
  decisions and remain deferred there; Phase 3 Savings card shows balance + monthly contributions.
- Engines consume the existing Phase-2 parsing output (`WorkspaceParser` and the typed domain
  records); no new parsing or validation rules are introduced beyond what those layers already
  provide. Multi-entry group validation already exists from Phase 2.
- The existing six locked seed accounts are retained; this phase corrects their `account_type` values
  to the canonical taxonomy and expands only the category seed.
- `swift test` requires a full Xcode toolchain and runs in CI; a CLT-only machine builds and runs the
  CLIs but cannot run the test target.
- The roadmap's Phase 3 critical-dependency note ([FIX-C2]) is corrected as part of this work: the
  master registry is `Accounts/accounts.csv` and account-groups come from
  `Accounts/account-groups.csv`; references to the deleted `Investments/accounts.csv` and the
  never-existent `Business/entities.csv` are removed.

## Dependencies

- **Phase 1** — workspace provisioning, file index, manifest, core models (`AccountModels`,
  `BudgetModels`, `CrossDomainModels` stubs).
- **Phase 2** — `CSVParserService` / `CSVSchemaRegistry` / `CSVNormalizer` / `WorkspaceParser`,
  `ValidationEngine` + `RuleCatalog`, `SettingsStore`. These must be stable (they are; merged in PR #16).
- **Build order** — `AccountEngine` (US1) before `BudgetEngine` (US2) before `OverviewEngine`/
  `LinkingEngine` (US3). Seed data (US4) can proceed in parallel once the taxonomy is fixed.

## Out of Scope

- All SwiftUI views and the Phase-3 UI design DECIDEs (→ Phase 5).
- `SavingsGoalEngine`, `PortfolioEngine`, `BenchmarkEngine`, `TaxEngine`, `TaxPrepEngine`,
  `TaxAdjustmentEngine` (→ Phase 4).
- Any write, edit, repair, or export flow (→ Phase 6) — this phase is strictly read-only.
- "Estimated rate" formulas for Savings/Investments KPI cards (→ Phase 4).
</content>
