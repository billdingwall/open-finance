# Validation Rules and UI Requirements

> Extracted from `docs/technical-design.md` in Round 7 (2026-06-24). The overview file
> (`technical-design.md`) links here for validation rule definitions and per-section UI specs.

---

## 1. Validation rules

### File-level validation
- missing required file
- unknown file type
- invalid file name
- duplicate monthly file
- invalid CSV header
- invalid date
- invalid decimal
- missing required front matter
- invalid enum value

### Cross-file validation
- unknown category reference
- unknown account-group reference
- unknown account reference
- unknown asset reference
- unknown liability reference
- unknown portfolio reference
- unknown sleeve reference
- unknown goal reference
- missing benchmark data
- duplicate transaction ID
- orphan note link
- **delete with reference check — default: reassign** (locked Round 7): before deleting a row, resolve inbound references (e.g. an account group referenced by accounts; an account referenced by transactions; a category referenced by transactions). The write preview must list referencing rows and present a reassignment picker per referencing collection (e.g. "Reassign 42 transactions to: [category picker]"). Nullable references may be left unlinked. The delete and all reassignments are written atomically; the user can cancel the entire operation. The app never silently drops referencing rows and never blocks a delete the user confirms with a valid reassignment. See `docs/product-requirements.md §12`.

### Domain validation
- budget period without budget rows
- goal contribution without goal
- asset without account
- trade without a sending or receiving asset
- multi-entry transfer group that does not net to zero (`SUM(amount) WHERE group_id = X ≠ 0`)
- gross/net group that does not reconcile (`net ≠ gross − Σ(withholding)`, or not exactly one `gross` and one `net` row)
- tax payment outside tax year
- business transaction with unknown account-group

### Repairable issue types
- missing optional column
- header casing mismatch
- missing seed file
- missing folder
- blank optional field normalization

### Manual-only issue types
- conflicting IDs
- ambiguous category remap
- impossible date repair
- duplicated but divergent transactions
- broken business entity linkage

---

## 2. UI requirements by section

### Overview
No filters. Fixed read-only dashboard.

Must show:
- KPI cards: monthly cash flow (Budget), total savings balance (Savings), total investment value (Investments), YTD net income (Business), estimated return (Taxes)
- Month-over-month panel: budget cash flow trend, savings & investments totals trend
- Issues table: validation issues surfaced inline, grouped by severity with repairable badge

### Accounts
The all-accounts overview must show:
- Card grid: grouped by customizable account group (Personal Accounts, Place of Employment, Business Groups) showing institution, type, monthly cash inflow, YTD net income. Account cards are clickable and open the per-account screen.
- Aggregate header: total monthly cash inflow, YTD net income, total active accounts across the workspace

Account-group detail screens (one screen per group, no sub-tabs) must show:
- An individual-accounts card section (the same account card as the all-accounts grid) above the transaction ledger
- **Business group**: monthly P&L-style summary (income, fixed expenses, discretionary, net income) with the monthly net-income chart, the transaction ledger **inline below the net-income chart**, expense category view, category budgets, and linked group notes/monthly reviews.
- **Employment group**: Payroll deposits, HSA/FSA benefits, employer stock vests (ESPP/RSU).
- **Personal group**: Net worth and cash flow trends, personal savings goals link.

Per-account detail screen (reached by selecting an account card) must show:
- Transactions table for the account; monthly gross income vs expenses/tax, YTD net income
- Transaction import, add, edit, and delete within account context
- Account rules and estimates view
- Edit in local screen actions; delete inside the edit flow (per write-flow UI placement convention in `data-pipelines.md §1`)

### Budget
Must show:
- Pie chart: breakdown of fixed expenses, discretionary, savings, investments as % of monthly net income
- Spend Mix and Spending Variance panels at an equal 50/50 split (neither dominant nor cut off)
- Monthly totals with plan-vs-actual variance per category
- 3-month trailing average per category (show partial average when fewer than 3 months available)
- Category and subcategory management with manual create and edit
- Category group totals
- Transaction ledger per period
- Contribution-to-goals summary

### Savings & Investments

**Goals** must show:
- Goal cards with progress bar, target amount, current balance, monthly contribution
- Monthly funding status per goal
- Goal-to-budget contribution links
- Linked transactions and notes per goal
- A single flat goal list — no active/archived grouping (goal lifecycle states are V2)

**Portfolio** must show:
- Holdings table as the primary surface (account-level and aggregate)
- Holdings table view toggle: standard holdings table ⇄ heat map table showing % growth per period (D, W, M, 3M, 6M, 1Y, 3Y, 5Y) — this replaces the dedicated benchmark view
- S&P 500 % growth comparison per account (Brokerage, Savings, IRA) and sector performance weighted against S&P 500, presented within the heat-map mode
- Account allocation view
- Tax-lot drill-down
- Sleeve table appended at the bottom: sleeve list with strategy description, monthly contribution target, target vs actual weights, drift indicator, linked strategy notes

### Taxes

**Current tax year** must show:
- YTD taxable income, taxes paid vs taxes owed, effective rate per account
- Estimated payment schedule by quarter and year (no separate Estimated Payments screen)
- Realized gain/loss summary and income summary — dividends, interest (no separate Gains & Income screen)
- Deductions view: standard vs itemized comparison, above-the-line deductions, Schedule C items linked to business entities (no separate Deductions screen)
- Taxable income minus deductibles projection
- Business tax-prep summary derived from categorized business expenses

It must NOT show the prep checklist — the checklist lives on its own screen.

**Prep checklist** must show:
- The prep checklist as the full-width, focal content of the screen — no competing elements
- Educational content explaining each tax-prep step to the user
- Complete, incomplete, and missing-input states
- Source links for each checklist item

**Tax archive** must show:
- Prior-year read-only archive selector
- Archived deductions and estimated payment history per closed year

### Notes *(V2)*
Must show:
- Note list
- Linked-entity context
- Front matter inspector
- Preview mode
- Source file path

### Issues *(V2)*
Must show:
- Grouped issues
- Severity
- Repairable badge
- Affected files
- Repair preview
