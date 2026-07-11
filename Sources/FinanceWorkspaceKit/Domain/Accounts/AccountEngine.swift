import Foundation

// T012-T016 — AccountEngine: the read-only master account read model. Pure function of
// (WorkspaceContext, asOf, settings). No writes, no Tax/Investment domain logic (FR-009).
// Income/expense are distinguished by SIGN (the ledger `type` enum is standard/trade/transfer);
// multi-entry paycheck groups carry gross/withholding/net role legs.

public struct AccountEngine: Sendable {

    public init() {}

    // MARK: - Classification

    /// A transaction's contribution to income / expense / taxes for net-income math.
    enum Contribution: Equatable { case income(Decimal), expense(Decimal), tax(Decimal), none }

    static func classify(_ tx: UnifiedTransaction) -> Contribution {
        guard tx.type != .transfer, tx.type != .trade else { return .none }   // internal / investment
        switch tx.groupRole {
        case .gross: return .income(abs(tx.amount))
        case .withholding: return .tax(abs(tx.amount))
        case .net, .credit, .debit: return .none      // net is gross−withholding; credit/debit are legs
        case .none:
            if tx.amount > 0 { return .income(tx.amount) }
            if tx.amount < 0 { return .expense(abs(tx.amount)) }
            return .none
        }
    }

    /// Signed cash effect of a row on its account, or nil when the row is excluded from the balance
    /// (the informational gross/withholding legs of a paycheck — the `net` row carries the cash;
    /// trade rows are Phase-4 investment cash).
    static func balanceDelta(_ tx: UnifiedTransaction) -> Decimal? {
        if tx.type == .trade { return nil }
        if tx.groupRole == .gross || tx.groupRole == .withholding { return nil }
        return tx.amount
    }

    // MARK: - Aggregation primitives

    private struct Figures { var gross: Decimal = 0; var expenses: Decimal = 0; var taxes: Decimal = 0 }

    /// Per-account, per-month figures across the whole ledger.
    private func monthlyFigures(_ txns: [UnifiedTransaction]) -> [String: [String: Figures]] {
        var out: [String: [String: Figures]] = [:]
        for tx in txns {
            let period = PeriodMath.month(tx.date)
            var fig = out[tx.accountId]?[period] ?? Figures()
            switch Self.classify(tx) {
            case let .income(value): fig.gross += value
            case let .expense(value): fig.expenses += value
            case let .tax(value): fig.taxes += value
            case .none: break
            }
            out[tx.accountId, default: [:]][period] = fig
        }
        return out
    }

    /// Derived balance per account (cash effect of all rows dated on/before the as-of month).
    private func balances(_ txns: [UnifiedTransaction], asOf: Date) -> [String: Decimal] {
        guard let end = PeriodMath.startOfMonthAfter(asOf) else { return [:] }
        var out: [String: Decimal] = [:]
        for tx in txns where tx.date < end {
            if let delta = Self.balanceDelta(tx) { out[tx.accountId, default: 0] += delta }
        }
        return out
    }

    // MARK: - Public projections

    public func overview(_ context: WorkspaceContext, asOf: Date,
                         settings: WorkspaceSettings) -> AccountsOverview {
        let accounts = context.accounts
        let txns = context.transactions
        let rules = context.accountRules
        let groupType = groupTypeByAccount(accounts, groups: context.accountGroups)
        let figures = monthlyFigures(txns)
        let balance = balances(txns, asOf: asOf)
        let asOfMonth = PeriodMath.asOfMonth(asOf)
        let taxYear = settings.taxYear

        var cards: [AccountSummaryCard] = []
        var totalInflow: Decimal = 0, totalNet: Decimal = 0
        var totalPersonal: Decimal = 0, totalRetained: Decimal = 0

        for account in accounts {
            let perMonth = figures[account.accountId] ?? [:]
            let ytd = ytdFigures(perMonth, taxYear: taxYear, asOf: asOf)
            let ytdNet = ytd.gross - ytd.expenses - ytd.taxes

            // Monthly inflow: the as-of month's gross income, or a rule projection when empty (FR-006).
            var monthInflow = perMonth[asOfMonth]?.gross ?? 0
            var isProjected = false
            if perMonth[asOfMonth] == nil {
                let projected = projectedMonthlyGross(for: account.accountId, rules: rules)
                if let projected { monthInflow = projected; isProjected = true }
            }

            cards.append(AccountSummaryCard(
                accountId: account.accountId, displayName: account.displayName,
                accountGroup: account.accountGroup, monthlyInflow: monthInflow,
                ytdNetIncome: ytdNet, currentBalance: balance[account.accountId] ?? 0,
                isProjected: isProjected))

            totalInflow += monthInflow
            totalNet += ytdNet
            // Personal-inflow vs retained-equity split (FR-001 / R12): business-group income is retained.
            if groupType[account.accountId] == .business {
                totalRetained += ytd.gross
            } else {
                totalPersonal += ytd.gross
            }
        }

        let groups = buildGroups(accounts: accounts, groups: context.accountGroups,
                                 groupType: groupType, figures: figures,
                                 taxYear: taxYear, asOf: asOf)

        return AccountsOverview(
            asOfMonth: asOfMonth, taxYear: taxYear, accounts: cards, groups: groups,
            totalMonthlyInflow: totalInflow, totalYTDNetIncome: totalNet,
            totalYTDPersonalInflow: totalPersonal, totalYTDRetainedEquity: totalRetained)
    }

    public func detail(for accountId: String, in context: WorkspaceContext, asOf: Date,
                       settings: WorkspaceSettings) -> AccountDetailProjection? {
        let accounts = context.accounts
        guard accounts.contains(where: { $0.accountId == accountId }) else { return nil }
        let txns = context.transactions
        let accountTxns = txns.filter { $0.accountId == accountId }
            .sorted { ($0.date, $0.transactionId) < ($1.date, $1.transactionId) }
        let perMonth = monthlyFigures(accountTxns)[accountId] ?? [:]
        let monthly = perMonth.keys.sorted().map { period -> AccountMonthFigures in
            let fig = perMonth[period] ?? Figures()
            return AccountMonthFigures(period: period, gross: fig.gross, expenses: fig.expenses, taxesPaid: fig.taxes)
        }
        let ytd = ytdFigures(perMonth, taxYear: settings.taxYear, asOf: asOf)
        let principal = liabilityPrincipal(for: accountId, txns: txns, asOf: asOf,
                                           liabilities: context.liabilities)
        return AccountDetailProjection(
            accountId: accountId, monthly: monthly, ytdNetIncome: ytd.gross - ytd.expenses - ytd.taxes,
            currentBalance: balances(accountTxns, asOf: asOf)[accountId] ?? 0,
            liabilityPrincipal: principal, transactions: accountTxns)
    }

    public func groupDetail(for accountGroupId: String, in context: WorkspaceContext, asOf: Date,
                            settings: WorkspaceSettings) -> AccountGroupProjection? {
        let accounts = context.accounts
        guard accounts.contains(where: { $0.accountGroupId == accountGroupId }) else { return nil }
        let groupType = groupTypeByAccount(accounts, groups: context.accountGroups)
        let figures = monthlyFigures(context.transactions)
        return buildGroups(accounts: accounts, groups: context.accountGroups,
                           groupType: groupType, figures: figures,
                           taxYear: settings.taxYear, asOf: asOf, only: accountGroupId).first
    }

    // MARK: - Internals

    private func groupTypeByAccount(_ accounts: [Account], groups: [AccountGroup]) -> [String: GroupType] {
        let typeByGroup = Dictionary(groups.map { ($0.accountGroupId, $0.groupType) }, uniquingKeysWith: { first, _ in first })
        var out: [String: GroupType] = [:]
        for account in accounts { out[account.accountId] = typeByGroup[account.accountGroupId] ?? .personal }
        return out
    }

    private func ytdFigures(_ perMonth: [String: Figures], taxYear: Int, asOf: Date) -> Figures {
        let months = Set(monthsInYTD(taxYear: taxYear, asOf: asOf))
        return perMonth.reduce(into: Figures()) { acc, kv in
            guard months.contains(kv.key) else { return }
            acc.gross += kv.value.gross; acc.expenses += kv.value.expenses; acc.taxes += kv.value.taxes
        }
    }

    private func monthsInYTD(taxYear: Int, asOf: Date) -> [String] {
        let asOfMonth = PeriodMath.asOfMonth(asOf)
        var months: [String] = []
        for m in 1...12 {
            let period = String(format: "%04d-%02d", taxYear, m)
            if period <= asOfMonth { months.append(period) }
        }
        return months
    }

    private func projectedMonthlyGross(for accountId: String, rules: [AccountRule]) -> Decimal? {
        let active = rules.filter { $0.accountId == accountId && $0.isActive }
        let positive = active.compactMap { $0.monthlyProjection }.filter { $0 > 0 }
        guard !positive.isEmpty else { return nil }
        return positive.reduce(0, +)
    }

    private func liabilityPrincipal(for accountId: String, txns: [UnifiedTransaction], asOf: Date,
                                    liabilities: [Liability]) -> Decimal? {
        let ids = Set(liabilities.filter { $0.accountId == accountId }.map(\.liabilityId))
        guard !ids.isEmpty, let end = PeriodMath.startOfMonthAfter(asOf) else { return nil }
        // Principal magnitude: net of draws (credit, positive) and payments (negative) on the liability.
        let delta = txns.filter { $0.date < end && ($0.liabilityId.map(ids.contains) ?? false) }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return abs(delta)
    }

    private func buildGroups(accounts: [Account], groups: [AccountGroup],
                             groupType: [String: GroupType],
                             figures: [String: [String: Figures]], taxYear: Int, asOf: Date,
                             only: String? = nil) -> [AccountGroupProjection] {
        let byGroup = Dictionary(grouping: accounts, by: \.accountGroupId)
        let monthsYTD = monthsInYTD(taxYear: taxYear, asOf: asOf)
        // Canonical group order (spec 010 UV-1): the accessor-ordered account-groups first, then
        // orphan group IDs (referenced by accounts but absent from account-groups.csv) in ID order.
        let knownIds = groups.map(\.accountGroupId).filter { byGroup[$0] != nil }
        let orphanIds = byGroup.keys.filter { id in !groups.contains { $0.accountGroupId == id } }.sorted()
        return (knownIds + orphanIds).compactMap { groupId -> AccountGroupProjection? in
            if let only, groupId != only { return nil }
            let groupAccounts = byGroup[groupId] ?? []
            let gType = groupType[groupAccounts.first?.accountId ?? ""] ?? .personal
            var net: Decimal = 0, retained: Decimal = 0
            var monthlyNet: [String: Decimal] = [:]
            for account in groupAccounts {
                let perMonth = figures[account.accountId] ?? [:]
                for (period, fig) in perMonth where monthsYTD.contains(period) {
                    let monthNet = fig.gross - fig.expenses - fig.taxes
                    net += monthNet
                    monthlyNet[period, default: 0] += monthNet
                    if gType == .business { retained += fig.gross }
                }
            }
            let pl: [BusinessMonthlySummary]? = gType == .business
                ? monthlyNet.keys.sorted().map {
                    BusinessMonthlySummary(accountGroupId: groupId, period: $0, netIncome: monthlyNet[$0] ?? 0)
                }
                : nil
            // groupAccounts preserves the accessor's canonical account order (Dictionary(grouping:)
            // keeps input order within each group) — do not re-sort by ID (spec 010 UV-1).
            return AccountGroupProjection(accountGroupId: groupId, groupType: gType,
                                          accountIds: groupAccounts.map(\.accountId),
                                          ytdNetIncome: net, ytdRetainedEquity: retained, businessPL: pl)
        }
    }
}
