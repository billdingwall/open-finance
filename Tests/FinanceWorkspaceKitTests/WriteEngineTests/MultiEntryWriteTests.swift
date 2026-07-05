import Testing
import Foundation
@testable import FinanceWorkspaceKit

// Phase 6 (007) T027 (US3) — reconciliation gates the write; groups are atomic.

@Suite struct MultiEntryWriteTests {
    private let header = ["transaction_id", "account_id", "date", "amount", "type", "group_id", "group_role"]

    @Test func balancedTransferReconciles() {
        let legs = [
            MultiEntryLeg(role: .standard, amount: -100),
            MultiEntryLeg(role: .standard, amount: 100),
        ]
        #expect(MultiEntry.reconciles(kind: .balanced, legs: legs))
    }

    @Test func unbalancedTransferDoesNotReconcile() {
        let legs = [MultiEntryLeg(role: .standard, amount: -100), MultiEntryLeg(role: .standard, amount: 90)]
        #expect(!MultiEntry.reconciles(kind: .balanced, legs: legs))
        // …and no plan is produced.
        #expect(MultiEntry.plan(kind: .balanced, month: "2026-06", groupId: "g1", legs: legs, header: header) == nil)
    }

    @Test func paycheckGrossNetReconciles() {
        let legs = [
            MultiEntryLeg(role: .gross, amount: 5000),
            MultiEntryLeg(role: .withholding, amount: 1200),
            MultiEntryLeg(role: .net, amount: 3800),
        ]
        #expect(MultiEntry.reconciles(kind: .grossNet, legs: legs))   // 3800 == 5000 − 1200
    }

    @Test func paycheckThatDoesNotBalanceIsRejected() {
        let legs = [
            MultiEntryLeg(role: .gross, amount: 5000),
            MultiEntryLeg(role: .withholding, amount: 1200),
            MultiEntryLeg(role: .net, amount: 4000),
        ]
        #expect(!MultiEntry.reconciles(kind: .grossNet, legs: legs))
    }

    @Test func balancedGroupWritesAllLegsToOneFileAtomically() throws {
        let legs = [
            MultiEntryLeg(role: .standard, amount: -100, fields: ["transaction_id": "t1", "account_id": "a1", "date": "2026-06-01", "amount": "-100", "type": "transfer"]),
            MultiEntryLeg(role: .standard, amount: 100, fields: ["transaction_id": "t2", "account_id": "a2", "date": "2026-06-01", "amount": "100", "type": "transfer"]),
        ]
        let plan = try #require(MultiEntry.plan(kind: .balanced, month: "2026-06", groupId: "grp-1", legs: legs, header: header))
        #expect(plan.changes.count == 1)                         // single file
        #expect(plan.changes[0].rowDiffs.count == 2)             // both legs
        #expect(plan.changes[0].rowDiffs.allSatisfy { $0.groupId == "grp-1" })
        // Each rendered row carries the shared group id.
        for diff in plan.changes[0].rowDiffs {
            if case .add(let line) = diff.kind { #expect(line.contains("grp-1")) }
        }
    }

    @Test func deletePlanRemovesEveryLeg() {
        let plan = MultiEntry.deletePlan(month: "2026-06", groupRows: [
            (rowRef: 3, line: "t1,a1,2026-06-01,-100,transfer,grp-1,standard"),
            (rowRef: 4, line: "t2,a2,2026-06-01,100,transfer,grp-1,standard"),
        ])
        #expect(plan.changes[0].rowDiffs.count == 2)
        #expect(plan.changes[0].rowDiffs.allSatisfy { if case .delete = $0.kind { return true } else { return false } })
    }
}
