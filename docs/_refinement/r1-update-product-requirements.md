# PRD Update Plan — Round 1

Source reviews: `docs/_refinement/review-r1.md`, `docs/_notes/account-types.md`, `docs/_notes/deduction-types.md`
Target: `docs/product-requirements.md`
Status: Applied 2026-06-08

---

## Summary

Round 1 prototype review plus two domain-research docs produce three types of changes:

1. **Structural** — navigation trimmed and reorganized, several views deferred to V2
2. **Module-level** — requirements updated to match what the prototype revealed about scope and usability
3. **Data model expansion** — account taxonomy and tax deduction taxonomy added from research docs

---

## Section-by-Section Changes

### Information architecture

The primary navigation needs a significant trim. The prototype review calls out too many top-level items and recommends deferring Notes, Issues, and Files to V2.

**Current nav:**
Overview, Budget, Savings Goals, Investments, Business, Taxes, Notes, Issues, Settings

**Revised nav:**
- Accounts _(new — income/expense management per taxable account)_
- Budget
- Savings & Investments _(merge Savings Goals + Investments)_
- Business
- Taxes
- Overview _(simplified dashboard, no filtering)_
- Settings
- Notes _(V2)_
- Issues _(V2)_
- Files _(V2)_

**Changes to PRD:**
- Update the "Recommended primary navigation" list
- Add a note that Notes, Issues, and Files are intentionally deferred to V2
- Move Issues table surface into the Overview section rather than its own nav item

---

### Overview / Dashboard

The prototype review marks Monthly Snapshots and Annual Snapshots views for deletion. The dashboard itself should be a single no-filter summary view with KPI cards and a month-over-month panel.

**Changes to PRD:**
- Remove Monthly Snapshots and Annual Snapshots from the scope list and IA
- Define the five Overview KPI cards explicitly:
  - Budget: monthly cash flow (income, estimated spending)
  - Savings: total savings balance (monthly contributions, estimated rate)
  - Investments: total investment value (monthly contributions, estimated rate)
  - Business: YTD net income (income, expenses)
  - Taxes: estimated return (gross income, taxes paid)
- Add right panel collapsible behavior as a UI requirement (closed by default, slide-over interaction rather than persistent split)
- Add Issues table surface to the Overview requirements (not a standalone section in v1)

---

### Accounts (new module)

The review introduces "Accounts" as a first-class module not present in the current PRD. This is the income and expense management layer per taxable account. The `account-types.md` research doc defines the full taxonomy.

**Changes to PRD:**
- Add Accounts module to functional requirements
- Account aggregate view: card overview per account, total monthly cash inflow, YTD net income (gross − expenses − tax), YTD cash inflow vs retained equity
- Individual account view: monthly gross income vs expense/tax, YTD net income, YTD cash inflow vs retained equity, import/add/edit transactions, add/edit account rules and estimates
- Add account type taxonomy to data model:
  - Employment (payroll, HSA, FSA, employer stock plans)
  - Business (business checking, business savings, merchant/payment gateways, corporate credit cards, petty cash)
  - Credit Cards (rewards, travel, retail, balance transfer)
  - Investments (taxable brokerage, IRA/Roth, robo-advisor, crypto, 529)
  - Savings (HYSA, traditional savings, CDs, money market, sinking funds)
  - Everyday Banking (personal/joint checking, cash management accounts)
  - Loans/Debt (mortgage, auto, student, personal, BNPL)

---

### Budget module

The prototype review calls for a functionality overhaul. The core shift: Current Month becomes a static overview rather than a live view, and the dashboard focuses on comparing defined budget targets against transaction history. Rules are deferred post-MVP.

**Changes to PRD:**
- Update Budget module requirements:
  - Current Month view repurposed as static budget overview with a pie chart (fixed expenses, discretionary, savings, investments as % of net monthly income)
  - Categories table should display 3-month trailing average for each category
  - Budget History view retained as month-over-month variance
  - Categories view expanded to full budget management (manual category and subcategory creation)
  - Budget planning: cash, fixed, spend, save, invest as percentage of total
- Remove Rules from v1 scope (defer to post-MVP)
- Update non-functional requirements to note that month-over-month tracking requires transaction imports; without sync, this is user-managed upkeep — the app should make this as low-friction as possible

---

### Savings & Investments (merged module)

Savings Goals and Investments are merged into a single "Savings & Investments" section. The prototype review treats them as one unified financial view.

**Changes to PRD:**
- Rename and merge the two module sections in functional requirements
- Savings side: goals, targets, monthly contributions, historical progress
- Investments side: portfolio overview, account-level holdings, sleeve definitions, performance
- Benchmark requirements now explicit:
  - Totals compared to S&P 500 (% growth) — per account: Brokerage, Savings, IRA
  - Performance table/heat map across periods: D, W, M, 3M, 6M, 1Y, 3Y, 5Y
  - Sector performance weighted against S&P 500

---

### Business module

No structural changes from the review beyond aligning with the new Accounts module. Business accounts and entities share the same account type taxonomy.

**Changes to PRD:**
- Align business account types with the Accounts taxonomy (Business group: business checking, savings, merchant gateways, corporate cards)
- No other changes — existing requirements are sound

---

### Taxes module

The `deduction-types.md` research doc significantly expands the tax module scope. The review adds a prep checklist and per-account tax summary.

**Changes to PRD:**
- Add deduction tracking to tax module requirements:
  - Standard deduction (filing status × year)
  - Above-the-line deductions: student loan interest, traditional IRA contributions, HSA contributions, educator expenses
  - Itemized deductions (Schedule A): SALT (capped), mortgage interest, medical expenses >7.5% AGI, charitable donations
  - Self-employed deductions (Schedule C): QBI deduction, home office, vehicle, self-employed health insurance, retirement contributions (SEP IRA, SIMPLE IRA, Solo 401k), operating expenses
  - New temporary deductions (2025–2028): overtime pay, tip income
- Add per-account tax view: taxes owed, paid, and effective rate per account
- Add tax prep checklist as a v1 surface (currently in scope implicitly but not defined)
- Add tax archive: prior-year deductions, estimated payment history
- Update data model — add to Taxes entities: `DeductionRecord`, `TaxArchiveYear`

---

### Notes, Issues, Files

**Changes to PRD:**
- Mark all three as V2 in scope section
- Remove from v1 user stories
- Retain the modules in the technical architecture as planned-but-deferred, not deleted

---

### UI / Shell requirements

The review introduces a specific pattern for the right panel that should be documented.

**Changes to PRD:**
- Right detail pane: collapsible, closed by default
- Slide-over interaction (not a persistent split pane)
- Add to Native behavior requirements

---

## Data model additions

| Domain | Entities to add |
|---|---|
| Accounts | `Account`, `AccountType`, `AccountRule`, `AccountEstimate` |
| Taxes | `DeductionRecord`, `TaxArchiveYear` |
| Platform | Update `FileRecord` to include per-account classification |

Update existing Investments entities: `BenchmarkSeries` already present — expand to include `BenchmarkPeriod` for the D/W/M/3M/6M/1Y/3Y/5Y heat map model.

---

## Proposed maintenance workflow

This PRD will evolve through prototype rounds. The goal is to keep it a lightweight but accurate direction doc without making every edit a big project.

### Folder conventions (already in use)

```
docs/
  product-requirements.md              ← primary direction doc
  _refinement/
    review-r{n}.md                     ← raw prototype/UX feedback per round
    update-product-requirements-r{n}.md ← this file: synthesis → change list
  _notes/
    account-types.md                   ← domain research (account types)
    deduction-types.md                 ← domain research (tax deductions)
```

### Review cycle

1. **Prototype round** — produce `_refinement/review-r{n}.md` with raw notes and screenshots
2. **Research docs** — add named research docs to `_notes/` as domain questions arise (already happening with account types and deduction types)
3. **Update plan** — synthesize all new review and research docs into an `update-product-requirements-r{n}.md` with a concrete change list per PRD section
4. **PRD edit** — apply the change list to `product-requirements.md`, marking changes with a changelog entry at the bottom
5. **Carry forward** — update the `update-product-requirements-r{n}.md` status to `Applied` and note the date

### PRD changelog section

Add a `## Changelog` section to the bottom of `product-requirements.md`. Format:

```
## Changelog

### Round 1 — 2026-06-08
- Added Accounts module
- Merged Savings Goals + Investments → Savings & Investments
- Deferred Notes, Issues, Files to V2
- Expanded tax deduction taxonomy
- Expanded account type taxonomy
- Simplified Overview dashboard; removed Monthly/Annual Snapshot views
- Deferred Budget Rules to post-MVP
```

### When to update the PRD vs. when to create a feature spec

- **Update PRD** when: a module's scope, goals, or requirements change; navigation or IA changes; data model expands
- **Create a feature spec** (via `/speckit-specify`) when: starting implementation of a specific module; need detailed acceptance criteria; ready to generate tasks

The PRD is the long-horizon direction doc. Feature specs are the per-module implementation contracts. Don't collapse them.

### Research doc naming

Use descriptive kebab-case file names in `_notes/` for domain research (already established with `account-types.md`, `deduction-types.md`). These accumulate over time and become reference material for both the PRD and implementation specs.

---

## Priority order for PRD edits

1. Navigation / IA restructure — everything downstream depends on this
2. Add Accounts module
3. Merge Savings Goals + Investments
4. Update Budget module requirements
5. Expand Taxes module
6. Update data model tables
7. Defer Notes/Issues/Files explicitly in scope section
8. Add changelog section
