import Testing
import Foundation
@testable import FinanceWorkspaceApp
@testable import FinanceWorkspaceKit

// 008 T020 (US2) — the reassignment picker's gating rules: apply stays blocked until EVERY
// referencing collection has a valid choice, the deleted object is never offered (nor accepted)
// as a target, and unlink is only valid where the FK is nullable / list-valued.

@MainActor
@Suite struct ReassignmentViewModelTests {

    private func makeModel(groups: [ReferenceGroup],
                           targets: [String] = ["C2", "C3"]) -> ReassignmentModel {
        ReassignmentModel(
            ref: SourceRef(filePath: "Budget/categories.csv", rowNumber: 1, provenance: .userEdited),
            rowRef: 1, before: "C1,Groceries,,CG1,discretionary,false",
            deletedId: "C1", groups: groups, targets: targets)
    }

    private var txGroup: ReferenceGroup {
        ReferenceGroup(collection: "transactions", column: "category_id",
                       rows: [RowRef(relativePath: "Accounts/transactions/2026-06.csv", rowRef: 4)],
                       nullable: true)
    }

    private var allocationGroup: ReferenceGroup {
        ReferenceGroup(collection: "budget-allocations", column: "category_id",
                       rows: [RowRef(relativePath: "Budget/budget-allocations.csv", rowRef: 1)],
                       nullable: false)
    }

    @Test func applyBlockedUntilEveryGroupChosen() {
        let model = makeModel(groups: [txGroup, allocationGroup])
        #expect(!model.canApply)

        model.selections[ReassignmentModel.key(txGroup)] = "C2"
        #expect(!model.canApply)                       // one of two chosen

        model.selections[ReassignmentModel.key(allocationGroup)] = "C3"
        #expect(model.canApply)                        // all chosen
        #expect(model.reassignments.count == 2)
    }

    @Test func deletedIdIsNeverACandidateAndIsRejectedAsAChoice() {
        let model = makeModel(groups: [txGroup], targets: ["C1", "C2"])   // scanner shouldn't, but belt+braces
        #expect(!model.candidates(for: txGroup).contains("C1"))

        model.selections[ReassignmentModel.key(txGroup)] = "C1"           // forced self-target
        #expect(model.target(for: txGroup) == nil)
        #expect(!model.canApply)
    }

    @Test func unlinkOnlyValidWhereNullableOrList() {
        let model = makeModel(groups: [txGroup, allocationGroup])

        model.selections[ReassignmentModel.key(txGroup)] = ReassignmentModel.unlinkChoice
        #expect(model.target(for: txGroup) == .unlink)                    // nullable → allowed

        model.selections[ReassignmentModel.key(allocationGroup)] = ReassignmentModel.unlinkChoice
        #expect(model.target(for: allocationGroup) == nil)                // required → rejected
        #expect(!model.canApply)
    }

    @Test func requiredGroupWithNoTargetsIsUnresolvable() {
        let model = makeModel(groups: [allocationGroup], targets: [])
        #expect(!model.isResolvable(allocationGroup))
        #expect(!model.canApply)
    }

    @Test func listValuedGroupOffersRemoveFromList() {
        let listGroup = ReferenceGroup(collection: "budgets", column: "account_group_ids",
                                       rows: [RowRef(relativePath: "Budget/budgets.csv", rowRef: 1)],
                                       nullable: false, isList: true)
        let model = makeModel(groups: [listGroup])
        #expect(model.allowsUnlink(listGroup))
        model.selections[ReassignmentModel.key(listGroup)] = ReassignmentModel.unlinkChoice
        #expect(model.target(for: listGroup) == .unlink)
        #expect(model.canApply)
    }
}
