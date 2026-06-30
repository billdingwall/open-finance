import Foundation

// T006/T007 — the seam between the Phase-2 generic `ParsedRecord` and the typed domain structs.
// Pure, total-on-valid-input, nil-on-invalid-required-field. Reads typed values straight off
// `FieldValue.typed` (no re-parsing). See contracts/record-mapping.md.

// MARK: - Typed field accessors

extension ParsedRecord {
    func string(_ column: String) -> String? {
        if case let .string(value)? = fields[column]?.typed, !value.isEmpty { return value }
        return nil
    }
    func decimal(_ column: String) -> Decimal? {
        if case let .decimal(value)? = fields[column]?.typed { return value }
        return nil
    }
    func date(_ column: String) -> Date? {
        if case let .date(value)? = fields[column]?.typed { return value }
        return nil
    }
    func bool(_ column: String) -> Bool? {
        if case let .boolean(value)? = fields[column]?.typed { return value }
        return nil
    }
    func int(_ column: String) -> Int? {
        if case let .integer(value)? = fields[column]?.typed { return value }
        return nil
    }
    /// Pipe-delimited list column (e.g. `account_group_ids`).
    func list(_ column: String) -> [String] {
        guard let raw = string(column) else { return [] }
        return raw.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

// MARK: - Mappers

public enum RecordMappers {

    public static func account(_ rec: ParsedRecord) -> Account? {
        guard let accountId = rec.string("account_id"),
              let groupRaw = rec.string("account_group"), let group = AccountGroupClass(rawValue: groupRaw),
              let accountType = rec.string("account_type"),
              let statusRaw = rec.string("status"), let status = AccountStatus(rawValue: statusRaw),
              let accountGroupId = rec.string("account_group_id") else { return nil }
        var investment: InvestmentMetadata?
        if rec.string("tax_treatment") != nil || rec.bool("performance_tracking") != nil {
            investment = InvestmentMetadata(taxTreatment: rec.string("tax_treatment"),
                                            performanceTracking: rec.bool("performance_tracking"))
        }
        return Account(accountId: accountId, displayName: rec.string("display_name") ?? accountId,
                       institution: rec.string("institution") ?? "", accountGroup: group,
                       accountType: accountType, status: status, accountGroupId: accountGroupId,
                       currentBalance: rec.decimal("current_balance"), investment: investment)
    }

    public static func accountGroup(_ rec: ParsedRecord) -> AccountGroup? {
        guard let id = rec.string("account_group_id"),
              let typeRaw = rec.string("group_type"), let groupType = GroupType(rawValue: typeRaw) else { return nil }
        return AccountGroup(accountGroupId: id, name: rec.string("name") ?? id, groupType: groupType)
    }

    public static func liability(_ rec: ParsedRecord) -> Liability? {
        guard let id = rec.string("liability_id"), let accountId = rec.string("account_id") else { return nil }
        return Liability(liabilityId: id, accountId: accountId,
                         principalBalance: rec.decimal("principal_balance"),
                         interestRate: rec.decimal("interest_rate"), termMonths: rec.int("term_months"))
    }

    public static func accountRule(_ rec: ParsedRecord) -> AccountRule? {
        guard let id = rec.string("rule_id"), let accountId = rec.string("account_id") else { return nil }
        let isActive = rec.bool("is_active") ?? true
        return AccountRule(ruleId: id, accountId: accountId,
                           ruleType: rec.string("rule_type").flatMap(AccountRule.RuleType.init(rawValue:)),
                           amount: rec.decimal("amount"),
                           frequency: rec.string("frequency").flatMap(AccountRule.Frequency.init(rawValue:)),
                           isActive: isActive)
    }

    public static func transaction(_ rec: ParsedRecord) -> UnifiedTransaction? {
        guard let id = rec.string("transaction_id"), let accountId = rec.string("account_id"),
              let date = rec.date("date"), let amount = rec.decimal("amount") else { return nil }
        let type = rec.string("type").flatMap(TransactionType.init(rawValue:)) ?? .standard
        return UnifiedTransaction(
            transactionId: id, accountId: accountId, date: date, amount: amount, type: type,
            categoryId: rec.string("category_id"), savingsGoalId: rec.string("savings_goal_id"),
            groupId: rec.string("group_id"),
            groupRole: rec.string("group_role").flatMap(GroupRole.init(rawValue:)),
            sendingAssetId: rec.string("sending_asset_id"), receivingAssetId: rec.string("receiving_asset_id"),
            liabilityId: rec.string("liability_id"), sourceFile: rec.sourceFile, sourceRow: rec.sourceRow)
    }

    public static func category(_ rec: ParsedRecord) -> Category? {
        guard let id = rec.string("category_id") else { return nil }
        let behavior = rec.string("default_budget_behavior").flatMap(BudgetBehavior.init(rawValue:)) ?? .discretionary
        return Category(categoryId: id, name: rec.string("name") ?? id,
                        parentCategoryId: rec.string("parent_category_id"),
                        categoryGroupId: rec.string("category_group_id"),
                        defaultBudgetBehavior: behavior, taxRelevant: rec.bool("tax_relevant") ?? false)
    }

    public static func budget(_ rec: ParsedRecord) -> Budget? {
        guard let id = rec.string("budget_id") else { return nil }
        return Budget(budgetId: id, name: rec.string("name") ?? id,
                      accountGroupIds: rec.list("account_group_ids"), accountIds: rec.list("account_ids"))
    }

    public static func budgetAllocation(_ rec: ParsedRecord) -> BudgetAllocation? {
        guard let id = rec.string("allocation_id"), let budgetId = rec.string("budget_id"),
              let categoryId = rec.string("category_id"), let planned = rec.decimal("planned_amount"),
              let period = rec.string("period") else { return nil }
        return BudgetAllocation(allocationId: id, budgetId: budgetId, categoryId: categoryId,
                                plannedAmount: planned, period: period)
    }

    public static func savingsGoal(_ rec: ParsedRecord) -> SavingsGoal? {
        guard let id = rec.string("goal_id") else { return nil }
        let status = rec.string("status").flatMap(SavingsGoalStatus.init(rawValue:)) ?? .active
        return SavingsGoal(goalId: id, name: rec.string("name") ?? id,
                           targetAmount: rec.decimal("target_amount") ?? 0,
                           targetDate: rec.date("target_date"), monthlyTarget: rec.decimal("monthly_target"),
                           sourceAccountId: rec.string("source_account_id"), status: status,
                           linkedNoteId: rec.string("linked_note_id"))
    }
}

// MARK: - WorkspaceContext convenience accessors (typed views over the parsed records)

extension WorkspaceContext {
    public var accounts: [Account] { records(ofType: "registry").compactMap(RecordMappers.account) }
    public var accountGroups: [AccountGroup] { records(ofType: "account-groups").compactMap(RecordMappers.accountGroup) }
    public var liabilities: [Liability] { records(ofType: "liabilities").compactMap(RecordMappers.liability) }
    public var accountRules: [AccountRule] { records(ofType: "account-rules").compactMap(RecordMappers.accountRule) }
    public var transactions: [UnifiedTransaction] { records(ofType: "transactions").compactMap(RecordMappers.transaction) }
    public var categories: [Category] { records(ofType: "categories").compactMap(RecordMappers.category) }
    public var budgets: [Budget] { records(ofType: "budgets").compactMap(RecordMappers.budget) }
    public var budgetAllocations: [BudgetAllocation] { records(ofType: "budget-allocations").compactMap(RecordMappers.budgetAllocation) }
    public var savingsGoals: [SavingsGoal] { records(ofType: "goals").compactMap(RecordMappers.savingsGoal) }
}
