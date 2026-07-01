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
                       currentBalance: rec.decimal("current_balance"), apy: rec.decimal("apy"),
                       investment: investment)
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

    // MARK: Phase 4 — Investments / Savings / Taxes (mapped against the shipped schemas)

    public static func savingsProgress(_ rec: ParsedRecord) -> SavingsProgress? {
        guard let id = rec.string("progress_id"), let goalId = rec.string("goal_id"),
              let asOf = rec.date("as_of"), let balance = rec.decimal("balance") else { return nil }
        return SavingsProgress(progressId: id, goalId: goalId, asOf: asOf, balance: balance)
    }

    public static func asset(_ rec: ParsedRecord) -> Asset? {
        guard let id = rec.string("asset_id") else { return nil }
        return Asset(assetId: id, ticker: rec.string("ticker"), name: rec.string("name") ?? id,
                     securityClass: rec.string("security_class"), accountId: rec.string("account_id"),
                     sleeveId: rec.string("sleeve_id"), currency: rec.string("currency"))
    }

    public static func pricePoint(_ rec: ParsedRecord) -> PricePoint? {
        guard let assetId = rec.string("asset_id"), let date = rec.date("date"),
              let close = rec.decimal("close") else { return nil }
        return PricePoint(assetId: assetId, date: date, close: close)
    }

    public static func dividend(_ rec: ParsedRecord) -> Dividend? {
        guard let id = rec.string("dividend_id"), let assetId = rec.string("asset_id"),
              let date = rec.date("date"), let amount = rec.decimal("amount") else { return nil }
        return Dividend(dividendId: id, assetId: assetId, date: date, amount: amount)
    }

    public static func taxLot(_ rec: ParsedRecord) -> TaxLot? {
        guard let id = rec.string("lot_id"), let assetId = rec.string("asset_id"),
              let acquired = rec.date("acquired_date"), let qty = rec.decimal("quantity"),
              let basis = rec.decimal("cost_basis") else { return nil }
        return TaxLot(lotId: id, assetId: assetId, acquiredDate: acquired, quantity: qty, costBasis: basis)
    }

    public static func portfolio(_ rec: ParsedRecord) -> Portfolio? {
        guard let id = rec.string("portfolio_id") else { return nil }
        return Portfolio(portfolioId: id, name: rec.string("name") ?? id,
                         accountId: rec.string("account_id"),
                         expectedReturnRate: rec.decimal("expected_return_rate"))
    }

    public static func sleeve(_ rec: ParsedRecord) -> PortfolioSleeve? {
        guard let id = rec.string("sleeve_id"), let portfolioId = rec.string("portfolio_id") else { return nil }
        return PortfolioSleeve(sleeveId: id, portfolioId: portfolioId, name: rec.string("name") ?? id)
    }

    public static func sleeveTarget(_ rec: ParsedRecord) -> SleeveTarget? {
        guard let sleeveId = rec.string("sleeve_id"), let weight = rec.decimal("target_weight") else { return nil }
        return SleeveTarget(sleeveId: sleeveId, targetWeight: weight)
    }

    public static func benchmarkPoint(_ rec: ParsedRecord) -> BenchmarkPoint? {
        guard let date = rec.date("date"), let close = rec.decimal("close") else { return nil }
        return BenchmarkPoint(date: date, close: close)
    }

    public static func taxAdjustment(_ rec: ParsedRecord) -> TaxAdjustment? {
        guard let id = rec.string("tax_adjustment_id"),
              let typeRaw = rec.string("adjustment_type"),
              let type = TaxAdjustmentType(rawValue: typeRaw),
              let amount = rec.decimal("amount"), let year = rec.int("tax_year") else { return nil }
        return TaxAdjustment(taxAdjustmentId: id, adjustmentType: type, amount: amount, taxYear: year,
                             status: rec.string("status") ?? "estimated", linkedId: rec.string("linked_id"))
    }

    public static func taxEstimate(_ rec: ParsedRecord) -> TaxEstimate? {
        guard let id = rec.string("estimate_id"), let year = rec.int("tax_year") else { return nil }
        return TaxEstimate(estimateId: id, taxYear: year, grossIncome: rec.decimal("gross_income"),
                           taxesPaid: rec.decimal("taxes_paid"), estimatedReturn: rec.decimal("estimated_return"))
    }

    public static func taxDocument(_ rec: ParsedRecord) -> TaxDocument? {
        guard let id = rec.string("document_id"), let year = rec.int("tax_year"),
              let kind = rec.string("kind") else { return nil }
        return TaxDocument(documentId: id, taxYear: year, kind: kind,
                           label: rec.string("label"), linkedPath: rec.string("linked_path"))
    }

    public static func estimatedPayment(_ rec: ParsedRecord) -> EstimatedPayment? {
        guard let id = rec.string("payment_id"), let year = rec.int("tax_year"),
              let quarter = rec.int("quarter"), let amount = rec.decimal("amount") else { return nil }
        return EstimatedPayment(paymentId: id, taxYear: year, quarter: quarter, amount: amount,
                                paid: rec.bool("paid") ?? false)
    }

    /// Investment trade from a `type = trade` ledger row. The asset is the receiving side for a buy,
    /// the sending side for a sell. Requires the optional `trade_type`/`quantity`/`price` columns.
    public static func trade(_ rec: ParsedRecord) -> Trade? {
        guard rec.string("type") == "trade",
              let id = rec.string("transaction_id"), let accountId = rec.string("account_id"),
              let date = rec.date("date"),
              let typeRaw = rec.string("trade_type"), let tradeType = TradeType(rawValue: typeRaw),
              let quantity = rec.decimal("quantity"), let price = rec.decimal("price") else { return nil }
        let assetId = tradeType == .buy ? rec.string("receiving_asset_id") : rec.string("sending_asset_id")
        guard let assetId else { return nil }
        return Trade(tradeId: id, accountId: accountId, assetId: assetId, date: date,
                     tradeType: tradeType, quantity: quantity, price: price)
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
    public var savingsProgress: [SavingsProgress] { records(ofType: "savings-progress").compactMap(RecordMappers.savingsProgress) }
    public var assets: [Asset] { records(ofType: "assets").compactMap(RecordMappers.asset) }
    public var prices: [PricePoint] { records(ofType: "prices").compactMap(RecordMappers.pricePoint) }
    public var dividends: [Dividend] { records(ofType: "dividends").compactMap(RecordMappers.dividend) }
    public var taxLots: [TaxLot] { records(ofType: "tax-lots").compactMap(RecordMappers.taxLot) }
    public var portfolios: [Portfolio] { records(ofType: "portfolios").compactMap(RecordMappers.portfolio) }
    public var sleeves: [PortfolioSleeve] { records(ofType: "sleeves").compactMap(RecordMappers.sleeve) }
    public var sleeveTargets: [SleeveTarget] { records(ofType: "sleeve-targets").compactMap(RecordMappers.sleeveTarget) }
    public var benchmarkSeries: [BenchmarkPoint] {
        records(ofType: "benchmark-series").compactMap(RecordMappers.benchmarkPoint).sorted { $0.date < $1.date }
    }
    public var taxAdjustments: [TaxAdjustment] { records(ofType: "tax-adjustments").compactMap(RecordMappers.taxAdjustment) }
    public var taxEstimates: [TaxEstimate] { records(ofType: "tax-estimates").compactMap(RecordMappers.taxEstimate) }
    public var taxDocuments: [TaxDocument] { records(ofType: "tax-documents").compactMap(RecordMappers.taxDocument) }
    public var estimatedPayments: [EstimatedPayment] { records(ofType: "estimated-payments").compactMap(RecordMappers.estimatedPayment) }

    /// Investment trades from the unified ledger (`type = trade` rows, sorted by date) — the FIFO
    /// lot source (research R1; ledger extended with trade_type/quantity/price).
    public var trades: [Trade] {
        records(ofType: "transactions").compactMap(RecordMappers.trade).sorted { $0.date < $1.date }
    }

    /// Prices grouped by asset, ascending by date — for last-close-on-or-before lookups.
    public var pricesByAsset: [String: [PricePoint]] {
        Dictionary(grouping: prices, by: \.assetId).mapValues { $0.sorted { $0.date < $1.date } }
    }
    /// The most recent `SavingsProgress` snapshot per goal.
    public var latestProgressByGoal: [String: SavingsProgress] {
        Dictionary(grouping: savingsProgress, by: \.goalId).compactMapValues { $0.max { $0.asOf < $1.asOf } }
    }
}
