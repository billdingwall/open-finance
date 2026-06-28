import Foundation

// T009 — Budget domain models.

public enum BudgetBehavior: String, Codable, Sendable, CaseIterable {
    case fixed, discretionary, savings, investment, transfer
}

public struct Category: Codable, Equatable, Sendable, Identifiable {
    public var categoryId: String
    public var name: String
    public var parentCategoryId: String?
    public var categoryGroupId: String?
    public var defaultBudgetBehavior: BudgetBehavior
    public var taxRelevant: Bool
    public var id: String { categoryId }

    public init(categoryId: String, name: String, parentCategoryId: String? = nil,
                categoryGroupId: String? = nil, defaultBudgetBehavior: BudgetBehavior = .discretionary,
                taxRelevant: Bool = false) {
        self.categoryId = categoryId
        self.name = name
        self.parentCategoryId = parentCategoryId
        self.categoryGroupId = categoryGroupId
        self.defaultBudgetBehavior = defaultBudgetBehavior
        self.taxRelevant = taxRelevant
    }
}

public struct Budget: Codable, Equatable, Sendable, Identifiable {
    public var budgetId: String
    public var name: String
    public var accountGroupIds: [String]
    public var accountIds: [String]
    public var id: String { budgetId }

    public init(budgetId: String, name: String, accountGroupIds: [String] = [],
                accountIds: [String] = []) {
        self.budgetId = budgetId
        self.name = name
        self.accountGroupIds = accountGroupIds
        self.accountIds = accountIds
    }
}

public struct BudgetAllocation: Codable, Equatable, Sendable, Identifiable {
    public var allocationId: String
    public var budgetId: String
    public var categoryId: String
    public var plannedAmount: Decimal
    public var period: String   // e.g. "2026-05"
    public var id: String { allocationId }

    public init(allocationId: String, budgetId: String, categoryId: String,
                plannedAmount: Decimal, period: String) {
        self.allocationId = allocationId
        self.budgetId = budgetId
        self.categoryId = categoryId
        self.plannedAmount = plannedAmount
        self.period = period
    }
}
