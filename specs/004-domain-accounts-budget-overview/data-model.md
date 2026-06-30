# Phase 1 Data Model: Domain Layer I — Accounts, Budget & Overview

All types are `Sendable` value types in `FinanceWorkspaceKit`. This phase **fleshes out** the
Phase-1 projection stubs (`AccountModels`, `BudgetModels`, `CrossDomainModels`) and adds the
record-mapping seam. No file schema changes — only added category seed *rows* and corrected seed
`account_type` *values* (no columns added/renamed, so `schema_version` is unchanged).

## A. Mapped domain entities (input side)

Mapped from `ParsedRecord` by `Domain/Mapping/RecordMappers.swift`. The structs already exist from
Phase 1; mapping populates them. Only fields the engines need are required.

| Entity | Source file-type | Key fields the engines read |
|---|---|---|
| `Account` | `registry` (`Accounts/accounts.csv`) | `accountId`, `accountGroup`, `accountType`, `status`, `accountGroupId`, `investment?` |
| `AccountGroup` | `account-groups` | `accountGroupId`, `name`, `groupType` |
| `Liability` | `liabilities` | `liabilityId`, `accountId` (principal derived) |
| `AccountRule` | `account-rules` | `ruleId`, `accountId`, `ruleType`, `amount`, `frequency`, `isActive` |
| `UnifiedTransaction` | `transactions` | `transactionId`, `accountId`, `date`, `amount`, `type`, `categoryId?`, `savingsGoalId?`, `groupId?`, `groupRole?`, `liabilityId?`, sleeve/asset ids |
| `Category` | `categories` | `categoryId`, `categoryGroupId?`, `defaultBudgetBehavior`, `taxRelevant` |
| `Budget` | `budgets` | `budgetId`, `accountGroupIds`, `accountIds` |
| `BudgetAllocation` | `allocations` | `allocationId`, `budgetId`, `categoryId`, `plannedAmount`, `period` |
| `SavingsGoal` | `goals` | `goalId`, (status for archived exclusion — only `active` shown) |

**Mapping rules**: read typed values from `FieldValue.typed`; a missing/invalid **required** field →
mapper returns `nil` and the row is skipped (its validation issue already exists in the Phase-2
stream). Optional fields map to `nil`. Provenance (`sourceFile`, `sourceRow`) is carried through where
the struct has the fields.

## B. AccountEngine projections (`Domain/Accounts/AccountModels.swift`, extended)

```
AccountsOverview                       // aggregate, the AccountsView feed
  asOfMonth: String                    // "YYYY-MM"
  taxYear: Int
  accounts: [AccountSummaryCard]
  groups: [AccountGroupProjection]
  totalMonthlyInflow: Decimal
  totalYTDNetIncome: Decimal
  totalYTDPersonalInflow: Decimal      // YTD income available for personal spending
  totalYTDRetainedEquity: Decimal      // YTD taxable income retained (not personally drawn)

AccountSummaryCard                     // (Phase-1 stub, extended)
  accountId: String
  displayName: String
  accountGroup: AccountGroupClass
  monthlyInflow: Decimal               // as-of month, transfers excluded
  ytdNetIncome: Decimal                // tax-year window
  currentBalance: Decimal              // derived from the ledger
  isProjected: Bool                    // true when figures came from rules/estimates (no txns this month)

AccountGroupProjection
  accountGroupId: String
  groupType: GroupType
  accountIds: [String]
  ytdNetIncome: Decimal
  ytdRetainedEquity: Decimal              // business income retained in the group's accounts (Phase 3)
  businessPL: [BusinessMonthlySummary]?   // populated only for groupType == .business

AccountDetailProjection                // per-account screen feed (Phase 5)
  accountId: String
  monthly: [AccountMonthFigures]       // gross / expenses / taxesPaid / net per month, transfers excluded
  ytdNetIncome: Decimal
  currentBalance: Decimal
  liabilityPrincipal: Decimal?         // derived, when the account holds a liability
  transactions: [UnifiedTransaction]   // in-context, resolved groups

AccountMonthFigures
  period: String                       // "YYYY-MM"
  gross: Decimal
  expenses: Decimal
  taxesPaid: Decimal                   // withholding legs + tax-category rows
  net: Decimal                         // gross − expenses − taxesPaid
```

**Net income (FR-005)**: `net = gross − expenses − taxesPaid`, `type = transfer` excluded both sides.
Per-group `gross`/`expenses` mapping per the spec; `taxesPaid` = explicit tax line items —
`group_role = withholding` paycheck legs + standalone tax-payment-category rows (research R4). YTD
aggregates the months in `[Jan 1 taxYear, asOf month]`.

**Retained equity (FR-001 / research R12)**: `ytdRetainedEquity` = YTD taxable income recognized in
non-personal accounts that is not drawn to personal spending. In Phase 3 = business-group income rows
that remain in the business accounts (not transferred to a personal-group account) within the YTD
window. `totalYTDPersonalInflow` = YTD non-transfer income into personal-spending accounts.
`personalInflow + retainedEquity` reconciles to total non-transfer income (SC-010). Investment/
reinvested-gain retained equity is Phase 4 (`AccountEngine` does not read `type = trade` rows, FR-009).

## C. BudgetEngine projections (`Domain/Budget/BudgetModels.swift`, extended)

```
BudgetOverviewProjection               // BudgetOverviewView feed
  budgetId: String
  period: String                       // "YYYY-MM"
  rows: [BudgetVarianceRow]
  spendMix: SpendMix                   // % of net monthly income
  totals: BudgetTotals
  goalContributions: [GoalContributionRow]   // savings_goal_id-tagged, first-class output

BudgetVarianceRow
  categoryId: String
  categoryName: String
  behavior: BudgetBehavior             // fixed/discretionary/savings/investment/transfer
  planned: Decimal
  actual: Decimal
  variance: Decimal                    // actual − planned
  trailingAverage: TrailingAverage

TrailingAverage                        // research R7
  value: Decimal?                      // nil only when monthsAvailable == 0
  monthsAvailable: Int                 // 0…3
  isPartial: Bool                      // monthsAvailable < 3

SpendMix                               // each as a percentage of net monthly income
  fixedPct, discretionaryPct, savingsPct, investmentPct: Decimal

BudgetTotals
  income, fixed, discretionary, transfers, savings, investments: Decimal
  netMonthlyIncome: Decimal            // income − (fixed + discretionary), transfers excluded

GoalContributionRow
  goalId: String
  period: String
  amount: Decimal
```

**Scope (FR-011)**: a `BudgetVarianceRow`'s `actual` sums ledger rows for the budget's resolved scope
(`accountGroupIds` ∪ `accountIds`) in `period`, matched to the allocation's `categoryId`.

## D. CrossDomain projections (`Domain/CrossDomain/CrossDomainModels.swift`, extended)

```
OverviewDashboard                      // OverviewView feed
  asOfMonth: String
  cards: [OverviewSummaryCard]         // exactly 5: budget, savings, investments, business, taxes
  monthOverMonth: [MonthlySnapshot]    // trailing 6 populated months, gaps skipped
  issues: [ValidationIssue]            // from the Phase-2 ValidationEngine

OverviewSummaryCard                    // (Phase-1 stub, extended)
  kind: String                         // "budget" | "savings" | "investments" | "business" | "taxes"
  state: State                         // .available | .dataNotAvailable
  primaryValue: Decimal?
  secondaryValue: Decimal?             // e.g. monthly contributions on the savings card
  // investments + taxes are always .dataNotAvailable this phase (PortfolioEngine/TaxEngine = Phase 4)

MonthlySnapshot                        // (Phase-1 stub) — one per populated month
  period: String
  netIncome: Decimal

GoalFundingLink                        // (Phase-1 stub) budget contribution → savings goal
  goalId, transactionId: String
SleeveFundingLink                      // (Phase-1 stub) investment contribution → sleeve
  sleeveId, transactionId: String
```

## E. Seed data (no schema change)

- **`AccountTypeTaxonomy`** (`Domain/Mapping/AccountTypeTaxonomy.swift`): canonical `account_type`
  values per `account_group` (FR-020). Used to (a) correct the six seed accounts and (b) provide a
  reference list; `account_type` remains a free-string schema column.
- **Default category seed** (`Platform/WorkspaceLayout.swift`): expanded `Budget/categories.csv` rows
  across six groups — Income, Essentials, Lifestyle, Savings, Investments, Transfers (FR-021), each
  with `default_budget_behavior` and `tax_relevant`. Header and `# schema_version: 1` row unchanged.

See `contracts/seed-data.md` for the exact taxonomy table and category rows.

## State & lifecycle

- Engines are stateless pure functions; no entity has in-engine lifecycle. The only lifecycle field
  read is `SavingsGoal.status` (archived goals excluded) and `Account.status` (only `active` accounts
  drive live figures; `closed`/`frozen` still resolve balances historically).
- `account_type` is validated against `AccountTypeTaxonomy` for **seed correctness** only; user values
  outside the list remain valid (free string).
</content>
