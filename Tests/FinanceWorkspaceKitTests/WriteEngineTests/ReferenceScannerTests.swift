import Testing
import Foundation
@testable import FinanceWorkspaceKit

// Phase 6 (007) T031 (US4) — the FK edge map is exhaustive against the shipped schemas (research D3);
// deletes never orphan a referencing row (SC-005).

@Suite struct ReferenceScannerTests {

    private func rec(_ file: String, _ row: Int, _ fields: [String: String]) -> ParsedRecord {
        ParsedRecord(fields: fields.mapValues { FieldValue(raw: $0, typed: .string($0), isValid: true) },
                     sourceFile: file, sourceRow: row)
    }

    private func result(_ key: String, _ path: String, _ records: [ParsedRecord]) -> CSVParseResult {
        CSVParseResult(fileTypeKey: key, filePath: path, records: records, warnings: [], schemaVersionFound: 1)
    }

    private func context(_ results: [CSVParseResult]) -> WorkspaceContext {
        WorkspaceContext(workspaceURL: URL(fileURLWithPath: "/tmp"), parseResults: results, notes: [])
    }

    // A category delete surfaces transactions, budget-allocations, and account-rules that reference it.
    @Test func categoryDeleteFindsAllReferencingCollections() {
        let ctx = context([
            result("transactions", "Accounts/transactions/2026-06.csv", [
                rec("Accounts/transactions/2026-06.csv", 1, ["transaction_id": "t1", "category_id": "cat-1"]),
                rec("Accounts/transactions/2026-06.csv", 2, ["transaction_id": "t2", "category_id": "cat-2"]),
            ]),
            result("budget-allocations", "Budget/budget-allocations.csv", [
                rec("Budget/budget-allocations.csv", 1, ["allocation_id": "a1", "category_id": "cat-1"]),
            ]),
            result("account-rules", "Accounts/account-rules.csv", [
                rec("Accounts/account-rules.csv", 1, ["rule_id": "r1", "category_id": "cat-1"]),
            ]),
        ])
        let groups = ReferenceScanner(context: ctx).referencesTo(id: "cat-1", parentSubtype: "categories")
        let collections = Set(groups.map(\.collection))
        #expect(collections == ["transactions", "budget-allocations", "account-rules"])
        // Only the cat-1 transaction, not cat-2.
        let txn = groups.first { $0.collection == "transactions" }
        #expect(txn?.rows.count == 1)
        #expect(txn?.rows.first?.rowRef == 1)
    }

    // An account delete surfaces the goal source account and the list-valued budget scope (I2 fix).
    @Test func accountDeleteFindsGoalSourceAndListBudgetScope() {
        let ctx = context([
            result("goals", "Savings/goals.csv", [
                rec("Savings/goals.csv", 1, ["goal_id": "g1", "source_account_id": "acct-1"]),
            ]),
            result("budgets", "Budget/budgets.csv", [
                rec("Budget/budgets.csv", 1, ["budget_id": "b1", "account_ids": "acct-1|acct-2"]),
                rec("Budget/budgets.csv", 2, ["budget_id": "b2", "account_ids": "acct-9"]),
            ]),
        ])
        let groups = ReferenceScanner(context: ctx).referencesTo(id: "acct-1", parentSubtype: "registry")
        #expect(groups.contains { $0.collection == "goals" && $0.column == "source_account_id" })
        let budgetGroup = groups.first { $0.collection == "budgets" }
        #expect(budgetGroup?.isList == true)
        #expect(budgetGroup?.rows.count == 1)          // only b1 contains acct-1 in its list
    }

    // A goal delete surfaces its owned progress snapshots (I2 fix).
    @Test func goalDeleteFindsProgressSnapshots() {
        let ctx = context([
            result("savings-progress", "Savings/progress.csv", [
                rec("Savings/progress.csv", 1, ["progress_id": "p1", "goal_id": "g1"]),
            ]),
        ])
        let groups = ReferenceScanner(context: ctx).referencesTo(id: "g1", parentSubtype: "goals")
        #expect(groups.contains { $0.collection == "savings-progress" })
    }

    // Reassignment targets exclude the deletion set (FR-022).
    @Test func reassignTargetsExcludeDeleted() {
        let ctx = context([
            result("categories", "Budget/categories.csv", [
                rec("Budget/categories.csv", 1, ["category_id": "cat-1"]),
                rec("Budget/categories.csv", 2, ["category_id": "cat-2"]),
                rec("Budget/categories.csv", 3, ["category_id": "cat-3"]),
            ]),
        ])
        let targets = ReferenceScanner(context: ctx)
            .reassignTargets(parentSubtype: "categories", excluding: ["cat-1"])
        #expect(targets == ["cat-2", "cat-3"])
    }
}
