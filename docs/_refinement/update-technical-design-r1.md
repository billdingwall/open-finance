# Technical Design Update Plan — Round 1

Source: `docs/product-requirements.md` (post Round 1 updates), `docs/_refinement/review-r1.md`
Target: `docs/technical-design.md`
Status: Applied 2026-06-08

---

## Summary

The PRD changed substantially in Round 1. The technical design predates those changes and diverges in 12 areas. Changes range from straightforward alignment (navigation, module names, V2 deferrals) to new content that doesn't exist in the design doc yet (Accounts file specs, deduction file specs, right panel behavior, Overview filters policy, 3-month trailing average logic).

---

## Change index

| # | Section | Type | Impact |
|---|---|---|---|
| 1 | §3 System overview | Minor alignment | Domain layer list missing accounts |
| 2 | §4 Information architecture | Significant | Navigation, sidebar structure, right panel, Overview filters |
| 3 | §6 Workspace folder structure | Additions | New Accounts/ folder, new tax files, remove rules.csv |
| 4 | §8 File specifications | New content | accounts.csv, account-rules.csv, deductions.csv, tax archive |
| 5 | §9 Metadata model | Minor addition | account_group field |
| 6 | §10 Internal data model | Additions | Account, DeductionRecord, TaxArchiveYear, BenchmarkPeriod |
| 7 | §11 Module layout | Additions | AccountEngine, UI/Accounts/, renamed UI/SavingsInvestments/ |
| 8 | §12 Service responsibilities | New content | AccountEngine description |
| 9 | §16 UI requirements | Significant | Accounts section, merged Savings & Investments, updated Taxes, V2 labels |
| 10 | §20 Rapid prototype order | Reorder | Accounts before validation, Issues/Notes deferred |
| 11 | §21 Decisions to lock | Update | Mark locked decisions, add new open questions |
| 12 | §23 Wireframes | Notation | Flag outdated wireframe references |

---

## Detailed changes

### §3 System overview — domain layer list

**Current:**
> Budget, savings, portfolio, business, tax, notes, and cross-domain linking.

**Proposed:**
> Accounts, budget, savings, investments, business, tax, notes, and cross-domain linking.

---

### §4 Information architecture

#### Primary navigation

**Current:**
```
Overview, Personal Budget, Savings Goals, Investments, Business, Taxes, Notes, Issues, Settings
```

**Proposed:**
```
Overview, Accounts, Budget, Savings & Investments, Business, Taxes, Settings
Notes (V2), Issues (V2), Files (V2)
```

#### Left sidebar nested structure

Full replacement. Current structure has several items that are now removed or changed:

| Item | Status |
|---|---|
| Overview → Monthly snapshots | Remove (deleted from PRD) |
| Overview → Annual snapshots | Remove (deleted from PRD) |
| Personal Budget → Rules | Remove (deferred post-MVP) |
| Savings Goals (standalone section) | Remove (merged into Savings & Investments) |
| Investments (standalone section) | Remove (merged into Savings & Investments) |
| Notes section + sub-items | Mark V2 |
| Issues section + sub-items | Mark V2 |
| Accounts section | Add (new) |
| Savings & Investments section | Add (replaces both Savings Goals and Investments) |

**Proposed sidebar structure (additions and changes only):**

New Accounts section:
```
Accounts
  All accounts
  Employment
  Business
  Credit Cards
  Investments
  Savings
  Checking
  Loans & Debt
  Specific account links
```

Revised Budget section (Rules removed):
```
Budget
  Overview
  Budget history
  Categories
  Specific category links
```

New Savings & Investments section (replaces both):
```
Savings & Investments
  Overview
  Goals
    Active goals
    Archived goals
    Specific goal links
  Portfolio
    Portfolio overview
    Accounts
    Sleeves
    Holdings
    Benchmarks
    Specific account links
    Specific sleeve links
```

Taxes section (add archive):
```
Taxes
  Current tax year
  Estimated payments
  Gains & income
  Deductions
  Tax archive
  Prep checklist
```

#### Right detail pane

Add to the right panel spec:

> The right detail pane is collapsible and closed by default. It should open as a slide-over interaction rather than a persistent split. The pane width should be fixed or lightly constrained to prevent it from competing with the main content surface.

#### Overview filters policy

Add a note to contextual filters:

> The Overview section has no filters. It is a fixed read-only dashboard. Filters apply only within module sections (Budget, Accounts, Savings & Investments, Business, Taxes).

---

### §6 Workspace folder structure

Three changes:

**1. Remove `Personal/rules.csv`**
Rules are deferred post-MVP. Remove from the tree and from folder design notes.

**2. Add `Accounts/` folder**
The new Accounts module needs a dedicated folder for the general account registry and account-level rules.

```
Accounts/
  accounts.csv
  account-rules.csv
```

**3. Expand `Taxes/` folder**
Add deduction tracking and a tax archive for prior years.

```
Taxes/
  estimated-payments.csv
  settings.csv
  deductions.csv          ← new
  archive/                ← new
    2025-deductions.csv
    2025-estimated-payments.csv
  yearly/
    2026-tax-notes.md
    2026-prep-checklist.md
```

**Updated tree (affected sections only):**

```text
Finance/
  Accounts/
    accounts.csv
    account-rules.csv
  Personal/
    transactions/
      2026-01.csv
    categories.csv
    budgets.csv
    savings-goal-contributions.csv
    ~~rules.csv~~             ← remove
  ...
  Taxes/
    estimated-payments.csv
    settings.csv
    deductions.csv
    archive/
      2025-deductions.csv
      2025-estimated-payments.csv
    yearly/
      2026-tax-notes.md
      2026-prep-checklist.md
```

---

### §8 File specifications

#### New: 8.21 Accounts registry CSV

Path:
`Accounts/accounts.csv`

Purpose: Master account registry covering all account type groups. This is the workspace-level source of truth for all accounts referenced across personal transactions, business transactions, and investment holdings.

Required columns:

| Column | Type | Notes |
|---|---|---|
| account_id | string | Stable unique ID |
| display_name | string | User-visible name |
| institution | string | Bank, brokerage, employer, etc. |
| account_group | enum | employment, business, credit_card, investment, savings, checking, loan |
| account_type | string | Specific type within group (e.g. roth_ira, hysa, mortgage) |
| is_active | boolean | |
| tax_relevant | boolean | Flag for tax module inclusion |
| tax_year_opened | integer | Optional |
| linked_entity_id | string | Optional — links business accounts to a BusinessEntity |
| notes | string | Optional |

Note: `Investments/accounts.csv` (spec 8.7) remains for investment-specific metadata (tax treatment, performance tracking). It links to the master registry via `account_id`. Other modules reference `account_id` from this master file.

#### New: 8.22 Account rules CSV

Path:
`Accounts/account-rules.csv`

Purpose: Account-level income and expense estimates used to project expected cash flow for an account (e.g. expected paycheck amount, recurring expense, loan payment schedule).

Required columns:

| Column | Type | Notes |
|---|---|---|
| rule_id | string | |
| account_id | string | |
| rule_type | enum | income_estimate, expense_estimate, recurring |
| description | string | |
| amount | decimal | |
| frequency | enum | monthly, biweekly, weekly, annual, quarterly |
| start_date | date | |
| end_date | date | Optional |
| category_id | string | Optional |
| is_active | boolean | |

#### New: 8.23 Tax deductions CSV

Path:
`Taxes/deductions.csv`

Purpose: Tracks expected deductions for the current and prior tax years. Supports all four deduction categories (standard, above-the-line, itemized/Schedule A, Schedule C).

Required columns:

| Column | Type | Notes |
|---|---|---|
| deduction_id | string | |
| tax_year | integer | |
| deduction_type | enum | standard, above_the_line, itemized, schedule_c |
| deduction_name | string | e.g. "HSA Contribution", "Home Office" |
| estimated_amount | decimal | |
| confirmed_amount | decimal | Optional — filled in at filing time |
| account_id | string | Optional — links to source account |
| entity_id | string | Optional — links Schedule C items to business entity |
| notes | string | Optional |
| status | enum | estimated, confirmed, not_applicable |

Standard deduction rows should be seeded by the app on workspace bootstrap with the correct amount for the filing status and tax year.

#### New: 8.24 Tax archive files

Path pattern:
`Taxes/archive/YYYY-deductions.csv`
`Taxes/archive/YYYY-estimated-payments.csv`

Purpose: Prior-year snapshots of deductions and estimated payments, written by the app at year-close or importable manually. Schema mirrors the active-year files. The presence of an archive file for a given year is the signal that the year is closed.

---

### §9 Metadata model

Add `account_group` to the required metadata attribute table:

| Attribute | Applies to | Purpose |
|---|---|---|
| account_group | Account files, transaction files | Group-level classification for account type routing |

---

### §10 Internal data model

**Add to Canonical entities:**
- `Account` (general master registry)
- `AccountRule`
- `AccountEstimate`
- `DeductionRecord`
- `TaxArchiveYear`

**Add to Investments entities:**
- `BenchmarkPeriod` (the D/W/M/3M/6M/1Y/3Y/5Y comparison window model)

**Add to Cross-domain entities:**
- `AccountSummaryCard` (the per-account card shown in the Accounts overview)
- `TaxDeductionSummary` (aggregated deduction view across types for a given year)

**Note on Account vs InvestmentAccount:**
`InvestmentAccount` (§8.7) remains as the investment-specific entity with tax treatment and performance metadata. The new `Account` entity is the master registry record. `InvestmentAccount` extends `Account` conceptually via `account_id`.

---

### §11 Module layout

**Add `Domain/Accounts/`:**
```
Domain/
  Accounts/
    AccountEngine.swift
    AccountModels.swift
```

**Expand `Domain/Taxes/`:**
```
Domain/
  Taxes/
    TaxEngine.swift
    TaxPrepEngine.swift
    DeductionEngine.swift    ← new
```

**Rename `UI/Savings/` → `UI/SavingsInvestments/`:**
The UI layer should reflect the merged module. At the domain layer, savings and investments can stay in separate subdirectories since their logic is independent.

**Add `UI/Accounts/`:**
```
UI/
  Accounts/          ← new
  Overview/
  Budget/
  SavingsInvestments/   ← renamed from Savings/ (Investments/ moves here too)
  Business/
  Taxes/
  Notes/             (V2)
  Issues/            (V2)
  Shared/
```

**Mark V2 in module layout:**
```
UI/
  Notes/       (V2)
  Issues/      (V2)
  Files/       (V2, not yet listed)
```

---

### §12 Service responsibilities

**Add AccountEngine:**
- build aggregate account overview (all accounts, monthly inflow, YTD net income, cash inflow vs retained equity)
- build per-account view (monthly gross income vs expenses/tax, YTD net income)
- apply account rules and estimates to project expected cash flow
- cross-reference with personal, business, and investment transaction records
- compute retained equity as cumulative net income over time

**Expand TaxEngine:**
Add deduction responsibility:
- `TaxEngine`: realized gains, estimated payments, income summary, per-account effective rate
- `TaxPrepEngine`: prep checklist, missing input detection, archive read/write
- `DeductionEngine`: deduction record management, standard deduction seeding, Schedule C cross-reference with BusinessEngine, taxable income minus deductibles projection

---

### §16 UI requirements

#### Overview (updated)

Replace the current list with:

Must show:
- KPI cards: monthly cash flow (Budget), total savings balance (Savings), total investment value (Investments), YTD net income (Business), estimated return (Taxes)
- Month-over-month panel: budget cash flow, savings & investments totals
- Issues table: validation issues surfaced inline, grouped by severity
- No filters

Remove:
- "sleeve drift" (implementation detail, not an overview KPI)
- References to snapshots (deleted from PRD)

#### Add: Accounts section

Must show:
- Card grid: one card per account showing institution, type, monthly cash inflow, YTD net income
- Aggregate header: total monthly cash inflow across all accounts, YTD net income, YTD cash inflow vs retained equity
- Per-account detail view: monthly gross income vs expenses/tax, YTD net income, transaction list
- Import, add, and edit transactions within account context
- Account rules and estimates view

#### Budget (updated)

Must show:
- Pie chart: breakdown of fixed expenses, discretionary, savings, investments as % of monthly net income
- Monthly totals with plan-vs-actual variance per category
- 3-month trailing average per category (requires handling of sparse data — show partial average when fewer than 3 months available)
- Category and subcategory management with manual create/edit
- Category group totals
- Transaction ledger per period

Remove:
- Recurring detection (was linked to Rules, now deferred)

#### Savings & Investments (replaces Savings Goals and Investments)

Must show (savings side):
- Goal cards with progress bar, target amount, current balance, monthly contribution
- Monthly funding status per goal
- Goal-to-budget contribution links

Must show (investments side):
- Holdings table (account-level and aggregate)
- Sleeve views with target vs actual weights
- Benchmark comparison — heat map table with periods D, W, M, 3M, 6M, 1Y, 3Y, 5Y
- S&P 500 % growth per account (Brokerage, Savings, IRA)
- Sector performance weighted against S&P 500
- Account allocation
- Tax-lot drill-down

#### Taxes (updated)

Must show:
- YTD taxable income, taxes paid vs taxes owed, effective rate per account
- Estimated payment schedule by quarter and year
- Realized gain/loss summary
- Income summary (dividends, interest)
- Deductions view: standard vs itemized comparison, above-the-line deductions, Schedule C items linked to business entities
- Taxable income minus deductibles projection
- Tax prep checklist with missing-input warnings
- Tax archive access for prior years
- Business tax-prep summary

#### Notes (V2)

Add V2 label. Keep the existing requirements for future reference.

#### Issues (V2)

Add V2 label. Issues are surfaced in the Overview table in v1.

---

### §20 Rapid prototype order

**Current:**
1. Workspace bootstrap and indexing
2. CSV and Markdown parsing
3. Validation and issues view
4. Overview projections
5. Personal budget and savings goals
6. Investments with sleeves and benchmark
7. Business entity reporting
8. Tax summaries and prep view
9. Structured write flows
10. Repair workflows

**Proposed:**
1. Workspace bootstrap and indexing
2. CSV and Markdown parsing
3. Overview projections (simplified dashboard, no filters)
4. Accounts module (master registry, per-account views)
5. Budget module (pie chart overview, category management, 3-month trailing averages)
6. Savings & Investments (goals + portfolio, benchmark heat map)
7. Business entity reporting
8. Tax module (deductions, per-account rates, prep checklist)
9. Structured write flows
10. Repair workflows
11. Notes viewer (V2)
12. Issues management view (V2)

Rationale: Accounts is foundational — personal, business, and investment transaction views all reference account_id from the master registry. Building it early makes subsequent modules simpler.

---

### §21 Decisions to lock before build

Several decisions listed as open are now locked by the PRD. Update to reflect:

**Locked:**
- App-owned iCloud container first ✓ (PRD scope: single-workspace, app-owned)
- Single workspace first ✓
- Strict canonical CSV schemas first ✓
- Notes deferred to V2 ✓
- Issues as standalone nav deferred to V2 ✓
- Budget rules deferred post-MVP ✓
- Benchmark import manual in v1 ✓

**Still open — need decision before build:**
- How does the master `Accounts/accounts.csv` relate to `Investments/accounts.csv`? Options: (a) master registry only, investment-specific file adds extra columns; (b) keep both files, link by account_id; (c) fold investment-specific columns into master registry with optional fields.
- How are Savings and Investments structured at the folder level? Currently separate (`Savings/`, `Investments/`). UI merges them, but file paths stay separate. Confirm this is the intent.
- Does the right detail pane start closed for all sections, or only some? (PRD says closed by default generally.)
- Deductions file: one unified `deductions.csv` or separate files per deduction type (standard, schedule-a, schedule-c)?
- Tax archive: written by user manually, triggered by an in-app "close year" action, or both?

---

### §23 Wireframes

The following wireframe references are outdated after Round 1 changes. Flag them with a note until new wireframes are produced:

| Wireframe | Issue |
|---|---|
| `02-overview.svg` | Monthly Snapshots and Annual Snapshots views removed; Issues now surfaced here |
| `03-personal-budget.svg` | Rules section removed; pie chart overview added |
| `04-savings-goals.svg` | Savings Goals is now part of unified Savings & Investments module |
| `05-investments.svg` | Investments is now part of unified Savings & Investments module |
| `08-notes.svg` | Notes deferred to V2 |
| `09-issues.svg` | Issues deferred to V2 as standalone view |

New wireframes needed (not yet produced):
- `accounts-overview.svg` — Accounts card grid and per-account view
- `savings-investments.svg` — Unified Savings & Investments view
- `budget-pie.svg` — Budget pie chart overview
- `taxes-deductions.svg` — Deductions tracking view
- `overview-updated.svg` — Revised Overview with Issues table
