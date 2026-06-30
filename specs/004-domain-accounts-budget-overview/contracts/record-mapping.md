# Contract: Record Mapping (`ParsedRecord` → typed domain entity)

`Domain/Mapping/RecordMappers.swift` is the seam between the Phase-2 generic `ParsedRecord` and the
Phase-1 typed structs. Pure, total-on-valid-input, `nil`-on-invalid-required-field.

## Shape

```swift
public enum RecordMappers {
    public static func account(_ r: ParsedRecord) -> Account?
    public static func accountGroup(_ r: ParsedRecord) -> AccountGroup?
    public static func liability(_ r: ParsedRecord) -> Liability?
    public static func accountRule(_ r: ParsedRecord) -> AccountRule?
    public static func transaction(_ r: ParsedRecord) -> UnifiedTransaction?
    public static func category(_ r: ParsedRecord) -> Category?
    public static func budget(_ r: ParsedRecord) -> Budget?
    public static func budgetAllocation(_ r: ParsedRecord) -> BudgetAllocation?
    public static func savingsGoal(_ r: ParsedRecord) -> SavingsGoal?
}
```

Convenience over `WorkspaceContext` (used by engines):

```swift
extension WorkspaceContext {
    public var accounts: [Account]                 // map(records(ofType: "registry"))
    public var accountGroups: [AccountGroup]
    public var liabilities: [Liability]
    public var accountRules: [AccountRule]
    public var transactions: [UnifiedTransaction]  // all monthly ledgers, flattened
    public var categories: [Category]
    public var budgets: [Budget]
    public var budgetAllocations: [BudgetAllocation]
    public var savingsGoals: [SavingsGoal]
}
```

## Rules

1. **Typed reads only**: pull from `FieldValue.typed` (`TypedValue.string/int/decimal/bool/date/list`).
   Never re-parse the `raw` string — Phase-2 normalization already ran.
2. **Required-field contract**: if a field the struct needs as non-optional is missing or
   `isValid == false`, return `nil`. The corresponding `ParseWarning`/`ValidationIssue` already exists
   in the Phase-2 stream — mapping must not duplicate it.
3. **Optional fields** map to `nil` when absent or blank.
4. **Enum coercion**: map raw enum strings to the domain enums (`AccountGroupClass`, `AccountStatus`,
   `GroupType`, `TransactionType`, `GroupRole`, `BudgetBehavior`); an unrecognized value → `nil` for a
   required enum, ignored for an optional one (already enum-validated in Phase 2).
5. **Provenance**: set `sourceFile`/`sourceRow` from the `ParsedRecord` where the struct carries them
   (e.g. `UnifiedTransaction`), for Phase-5 traceability.
6. **List fields** (e.g. budget `account_group_ids`, pipe-delimited): use `TypedValue.listValue`.
7. **Determinism/order**: mapping preserves record order within a file and file order across the
   `transactions` ledger set (sorted by filename / period) so downstream sums are stable.

## Column → field map (abbreviated; full names in `containers-and-budgets.md §3`)

| Struct | Column → field |
|---|---|
| `Account` | `account_id→accountId`, `account_group→accountGroup`, `account_type→accountType`, `status→status`, `account_group_id→accountGroupId`, `tax_treatment/performance_tracking→investment` |
| `UnifiedTransaction` | `transaction_id`, `account_id`, `date`, `amount`, `type`, `category_id`, `savings_goal_id`, `group_id`, `group_role`, `liability_id`, `sleeve_id`, `sending_asset_id`, `receiving_asset_id` |
| `Category` | `category_id`, `category_group_id`, `parent_category_id`, `default_budget_behavior`, `tax_relevant` |
| `Budget` | `budget_id`, `account_group_ids`(list), `account_ids`(list) |
| `BudgetAllocation` | `allocation_id`, `budget_id`, `category_id`, `amount→plannedAmount`, `period` |
| `AccountRule` | `rule_id`, `account_id`, `rule_type`, `amount`, `frequency`, `is_active` |
| `Liability` | `liability_id`, `account_id` (principal derived, not mapped from CSV) |
| `AccountGroup` | `account_group_id`, `name`/`display_name`, `group_type` |
| `SavingsGoal` | `goal_id`, `status` |

> Note: the Phase-1 `AccountRule` stub is generic (`kind`/`value`); this phase extends it (or adds an
> `AccountRuleDetail`) to carry `ruleType`/`amount`/`frequency`/`isActive` so FR-006 projection works.
> Pick the minimal extension that keeps the existing `AccountRule` callers compiling.
