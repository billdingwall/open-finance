# Contract: Domain Engine Surfaces

All engines are `Sendable`, stateless, and **read-only**. Each public entry point is a pure function
of `(WorkspaceContext, asOf: Date, settings: WorkspaceSettings)`. No engine writes to the workspace or
reads the system clock. Projections are the value types in `data-model.md`.

## AccountEngine (built first)

```swift
public struct AccountEngine: Sendable {
    public init()

    /// Aggregate Accounts overview (all accounts + groups), as of `asOf`.
    public func overview(_ context: WorkspaceContext, asOf: Date,
                         settings: WorkspaceSettings) -> AccountsOverview

    /// Per-account detail projection (monthly gross/expenses/tax, YTD, derived balance, in-context txns).
    public func detail(for accountId: String, in context: WorkspaceContext, asOf: Date,
                       settings: WorkspaceSettings) -> AccountDetailProjection?

    /// Per-group detail (business P&L populated for business groups).
    public func groupDetail(for accountGroupId: String, in context: WorkspaceContext, asOf: Date,
                            settings: WorkspaceSettings) -> AccountGroupProjection?
}
```

**Guarantees**
- Read-only projection interfaces only; no Tax/Investment domain logic (FR-009). `type = trade` rows
  are ignored here.
- Balances and `Liability.principal_balance` are ledger-derived, not read from cached columns (FR-004).
- YTD anchored to `settings.taxYear`; `taxes_paid` from explicit tax line items — withholding legs +
  standalone tax-payment rows (FR-005).
- Reports the YTD **personal cash inflow vs retained equity** split (Phase-3 retained equity =
  business income retained in business accounts; the two reconcile to total non-transfer income) —
  FR-001 / SC-010.
- `type = transfer` excluded from gross and expenses; multi-entry groups resolved without
  double-counting (FR-005/FR-007).
- Accounts with no transactions in the as-of month get rule/estimate-projected figures with
  `isProjected = true` (FR-006).
- Multiple `employment` groups aggregate independently and correctly (FR-008).
- Empty/sparse input → well-formed empty projection, never crash/nil/misleading-zero (FR-023).

## BudgetEngine

```swift
public struct BudgetEngine: Sendable {
    public init()

    /// Plan-vs-actual overview for one budget and period.
    public func overview(budgetId: String, period: String, in context: WorkspaceContext,
                         asOf: Date) -> BudgetOverviewProjection?

    /// Trailing average for one category ending the month before `period`.
    public func trailingAverage(categoryId: String, endingBefore period: String,
                                in context: WorkspaceContext) -> TrailingAverage
}
```

**Guarantees**
- Variance is computed over the budget's resolved scope (`accountGroupIds` ∪ `accountIds`) (FR-011).
- `trailingAverage` returns `(value, monthsAvailable, isPartial)`; partial when <3 months; never
  zero/blank for a category with ≥1 month (FR-012).
- `spendMix` expresses fixed/discretionary/savings/investment as % of net monthly income (FR-013).
- `goalContributions` surfaces `savings_goal_id`-tagged rows as a first-class output (FR-014).

## LinkingEngine

```swift
public struct LinkingEngine: Sendable {
    public init()
    public func goalLinks(in context: WorkspaceContext) -> [GoalFundingLink]
    public func sleeveLinks(in context: WorkspaceContext) -> [SleeveFundingLink]
}
```

**Guarantees**: builds links from `savings_goal_id` (goal) and sleeve/asset references (sleeve) on the
unified ledger (FR-015). Dangling references are surfaced via the existing validation stream, not
invented.

## OverviewEngine

```swift
public struct OverviewEngine: Sendable {
    public init(accountEngine: AccountEngine = .init(),
                budgetEngine: BudgetEngine = .init(),
                linkingEngine: LinkingEngine = .init())

    public func dashboard(_ context: WorkspaceContext, asOf: Date,
                          settings: WorkspaceSettings) -> OverviewDashboard
}
```

**Guarantees**
- Exactly five cards. Budget/Savings/Business `.available` (Budget←BudgetEngine; Savings/Business←
  AccountEngine); Investments/Taxes `.dataNotAvailable` (FR-016/FR-017).
- `monthOverMonth` = trailing 6 populated months, gaps skipped (FR-018).
- `issues` mirrors the Phase-2 `ValidationEngine` grouped output (FR-019).
- Never returns nil cards or placeholder zeros for the stub domains.

## Cross-cutting contract

- **Read-only** (FR-025): no engine opens a file for writing; verified by a test asserting workspace
  bytes are unchanged after a full projection run (SC-009).
- **Determinism**: identical `(context, asOf, settings)` → identical projections.
- **Resilience** (FR-023): unknown/dangling ids and sparse data degrade to empty/partial results.
</content>
