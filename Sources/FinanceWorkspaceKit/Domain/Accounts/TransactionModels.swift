import Foundation

// T008 — Unified transaction ledger row (`Accounts/transactions/YYYY-MM.csv`).
// Sign convention: negative = debit (money out), positive = credit (money in).

public enum TransactionType: String, Codable, Sendable, CaseIterable {
    case standard, trade, transfer
}

/// Role within a multi-entry group (transfers, paycheck gross/net splits).
public enum GroupRole: String, Codable, Sendable, CaseIterable {
    case gross, net, withholding, credit, debit
}

public struct UnifiedTransaction: Codable, Equatable, Sendable, Identifiable {
    public var transactionId: String
    public var accountId: String
    public var date: Date
    public var amount: Decimal
    public var type: TransactionType
    public var categoryId: String?
    public var savingsGoalId: String?
    // multi-entry connector — group_id is a shared connector, not a primary key
    public var groupId: String?
    public var groupRole: GroupRole?
    // investment / transfer links
    public var sendingAssetId: String?
    public var receivingAssetId: String?
    public var liabilityId: String?
    // provenance
    public var sourceFile: String?
    public var sourceRow: Int?

    public var id: String { transactionId }

    public init(transactionId: String, accountId: String, date: Date, amount: Decimal,
                type: TransactionType = .standard, categoryId: String? = nil,
                savingsGoalId: String? = nil, groupId: String? = nil, groupRole: GroupRole? = nil,
                sendingAssetId: String? = nil, receivingAssetId: String? = nil,
                liabilityId: String? = nil, sourceFile: String? = nil, sourceRow: Int? = nil) {
        self.transactionId = transactionId
        self.accountId = accountId
        self.date = date
        self.amount = amount
        self.type = type
        self.categoryId = categoryId
        self.savingsGoalId = savingsGoalId
        self.groupId = groupId
        self.groupRole = groupRole
        self.sendingAssetId = sendingAssetId
        self.receivingAssetId = receivingAssetId
        self.liabilityId = liabilityId
        self.sourceFile = sourceFile
        self.sourceRow = sourceRow
    }
}
