import Foundation
import FinanceWorkspaceKit

// T037 — Accounts presentation mapper (FR-017/018/019/020): AccountsOverview passthrough,
// group/account screen feeds (via the engines, over the snapshot's one consistent parse),
// ledger grouping, rules panel rows, linked-note references. No finance math — figures pass
// through from `AccountEngine`; the only arithmetic is presentation aggregation of
// engine-provided balances for the net-worth header line (labeled derived).

struct AccountsViewModel {
    let projections: WorkspaceProjections

    var overview: AccountsOverview { projections.accounts }

    // MARK: - Aggregate header (net-worth view)

    struct AggregateHeader {
        var assets: Decimal
        var liabilities: Decimal
        var netWorth: Decimal
        var monthlyInflow: Decimal
        var ytdNetIncome: Decimal
        var personalInflow: Decimal
        var retainedEquity: Decimal
    }

    /// Assets/liabilities split of the engine-provided per-account balances (sign split of
    /// already-derived balances; labeled `derived` in the UI).
    var header: AggregateHeader {
        let balances = overview.accounts.map(\.currentBalance)
        let assets = balances.filter { $0 > 0 }.reduce(Decimal(0), +)
        let liabilities = balances.filter { $0 < 0 }.reduce(Decimal(0), +)
        return AggregateHeader(
            assets: assets, liabilities: liabilities, netWorth: assets + liabilities,
            monthlyInflow: overview.totalMonthlyInflow, ytdNetIncome: overview.totalYTDNetIncome,
            personalInflow: overview.totalYTDPersonalInflow,
            retainedEquity: overview.totalYTDRetainedEquity)
    }

    // MARK: - Grouping

    struct GroupSection: Identifiable {
        var group: AccountGroupProjection
        var name: String
        var cards: [AccountSummaryCard]
        var id: String { group.accountGroupId }
    }

    var groupSections: [GroupSection] {
        let cardsById = Dictionary(overview.accounts.map { ($0.accountId, $0) },
                                   uniquingKeysWith: { first, _ in first })
        return overview.groups.map { group in
            GroupSection(group: group, name: groupName(group.accountGroupId),
                         cards: group.accountIds.compactMap { cardsById[$0] })
        }
    }

    func groupName(_ accountGroupId: String) -> String {
        projections.context.accountGroups.first { $0.accountGroupId == accountGroupId }?.name
            ?? accountGroupId
    }

    func accountName(_ accountId: String) -> String {
        overview.accounts.first { $0.accountId == accountId }?.displayName ?? accountId
    }

    // MARK: - Group screen feed (FR-018)

    func groupProjection(_ accountGroupId: String) -> AccountGroupProjection? {
        overview.groups.first { $0.accountGroupId == accountGroupId }
    }

    /// The group's inline ledger: its accounts' rows, folded into grouped entries (FR-020).
    func groupLedger(_ accountGroupId: String) -> [LedgerEntry] {
        guard let group = groupProjection(accountGroupId) else { return [] }
        let accountIds = Set(group.accountIds)
        let rows = projections.context.transactions.filter { accountIds.contains($0.accountId) }
        return LedgerEntry.entries(from: rows, categoryNames: categoryNames)
    }

    func businessPLPoints(_ group: AccountGroupProjection) -> [BarPoint] {
        (group.businessPL ?? []).map { BarPoint(label: Format.monthName($0.period), value: $0.netIncome) }
    }

    /// Budget variance rows for a budget scoped to this account group (engine-provided).
    func categoryBudgetRows(_ group: AccountGroupProjection, period: String? = nil) -> [BudgetVarianceRow] {
        guard let budget = projections.context.budgets
            .first(where: { $0.accountGroupIds.contains(group.accountGroupId) }) else { return [] }
        return BudgetEngine()
            .overview(budgetId: budget.budgetId, period: period ?? projections.accounts.asOfMonth,
                      in: projections.context, asOf: projections.asOf)?.rows ?? []
    }

    /// Linked-note references for the group's accounts (references only — Notes viewer is V2).
    func linkedNotes(_ group: AccountGroupProjection) -> [NoteRecord] {
        let accountIds = Set(group.accountIds)
        return projections.context.notes.filter { note in
            !accountIds.isDisjoint(with: note.linkedAccountIDs)
        }
    }

    // MARK: - Account screen feed (FR-019)

    func accountDetail(_ accountId: String) -> AccountDetailProjection? {
        AccountEngine().detail(for: accountId, in: projections.context,
                               asOf: projections.asOf, settings: projections.settings)
    }

    func accountLedger(_ detail: AccountDetailProjection) -> [LedgerEntry] {
        LedgerEntry.entries(from: detail.transactions, categoryNames: categoryNames)
    }

    /// Gross vs expenses vs taxes per month, as grouped-bar series (values pass through).
    func monthlySeries(_ detail: AccountDetailProjection) -> [GroupedBarPoint] {
        detail.monthly.flatMap { month in
            [GroupedBarPoint(label: Format.monthName(month.period), series: "Gross", value: month.gross),
             GroupedBarPoint(label: Format.monthName(month.period), series: "Expenses", value: month.expenses),
             GroupedBarPoint(label: Format.monthName(month.period), series: "Taxes", value: month.taxesPaid)]
        }
    }

    func rules(_ accountId: String) -> [AccountRule] {
        projections.context.accountRules.filter { $0.accountId == accountId }
    }

    // MARK: - Shared

    var categoryNames: [String: String] { projections.categoryNames }
}
