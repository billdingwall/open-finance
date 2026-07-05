import Testing
import Foundation
@testable import FinanceWorkspaceKit

// Phase 6 (007) T008 — CSVRowSerializer.applyDiffs byte-level guarantees (S2/S4) and edit correctness.

@Suite struct CSVRowSerializerTests {

    private let sample = """
    # schema_version: 1
    goal_id,name,target_amount,source_account_id
    goal-1,Emergency,10000,acct-1
    goal-2,Vacation,5000,acct-2
    goal-3,Car,20000,acct-3
    """

    // S2 — an empty diff list returns the input byte-for-byte.
    @Test func emptyDiffIsByteStable() throws {
        let out = try CSVRowSerializer.applyDiffs([], to: sample)
        #expect(out == sample)
    }

    // S4 — the schema_version comment and header row are preserved; only the target row changes.
    @Test func modifyPreservesCommentHeaderAndUntouchedRows() throws {
        let diff = WriteRowDiff(rowRef: 2, kind: .modify(
            before: "goal-2,Vacation,5000,acct-2",
            after: "goal-2,Vacation,6500,acct-2"))
        let out = try CSVRowSerializer.applyDiffs([diff], to: sample)
        let lines = out.components(separatedBy: "\n")
        #expect(lines[0] == "# schema_version: 1")
        #expect(lines[1] == "goal_id,name,target_amount,source_account_id")
        #expect(lines[2] == "goal-1,Emergency,10000,acct-1")   // untouched
        #expect(lines[3] == "goal-2,Vacation,6500,acct-2")     // modified
        #expect(lines[4] == "goal-3,Car,20000,acct-3")         // untouched
    }

    @Test func deleteRemovesOnlyTheTargetRow() throws {
        let diff = WriteRowDiff(rowRef: 1, kind: .delete(before: "goal-1,Emergency,10000,acct-1"))
        let out = try CSVRowSerializer.applyDiffs([diff], to: sample)
        #expect(!out.contains("goal-1"))
        #expect(out.contains("goal-2,Vacation,5000,acct-2"))
        #expect(out.contains("goal-3,Car,20000,acct-3"))
    }

    @Test func addAppendsAfterExistingData() throws {
        let diff = WriteRowDiff(rowRef: nil, kind: .add(after: "goal-4,Boat,30000,acct-1"))
        let out = try CSVRowSerializer.applyDiffs([diff], to: sample)
        #expect(out.components(separatedBy: "\n").last == "goal-4,Boat,30000,acct-1")
    }

    // Multiple modify/delete apply against stable indices (highest-first internally).
    @Test func multipleEditsUseOriginalIndices() throws {
        let diffs = [
            WriteRowDiff(rowRef: 1, kind: .delete(before: "goal-1,Emergency,10000,acct-1")),
            WriteRowDiff(rowRef: 3, kind: .modify(before: "goal-3,Car,20000,acct-3",
                                                  after: "goal-3,Car,25000,acct-3")),
        ]
        let out = try CSVRowSerializer.applyDiffs(diffs, to: sample)
        #expect(!out.contains("goal-1"))
        #expect(out.contains("goal-3,Car,25000,acct-3"))
        #expect(out.contains("goal-2,Vacation,5000,acct-2"))
    }

    // A `before` that no longer matches the file is rejected (drift within a row).
    @Test func mismatchedBeforeThrows() throws {
        let diff = WriteRowDiff(rowRef: 2, kind: .modify(before: "goal-2,STALE,0,acct-2",
                                                         after: "goal-2,Vacation,1,acct-2"))
        #expect(throws: WriteError.self) {
            try CSVRowSerializer.applyDiffs([diff], to: sample)
        }
    }

    @Test func outOfRangeRowRefThrows() throws {
        let diff = WriteRowDiff(rowRef: 99, kind: .delete(before: "x"))
        #expect(throws: WriteError.self) {
            try CSVRowSerializer.applyDiffs([diff], to: sample)
        }
    }

    // T009 — value→row orders fields by the file's header regardless of dict order.
    @Test func rowOrdersFieldsByHeader() throws {
        let header = try #require(CSVRowSerializer.header(of: sample))
        #expect(header == ["goal_id", "name", "target_amount", "source_account_id"])
        let line = CSVRowSerializer.row(
            fields: ["name": "Boat", "goal_id": "goal-9", "source_account_id": "acct-1", "target_amount": "30000"],
            header: header)
        #expect(line == "goal-9,Boat,30000,acct-1")
    }

    // T009 — a value containing a comma is quote-escaped, and an add round-trips through applyDiffs.
    @Test func addRoundTripsWithEscaping() throws {
        let header = try #require(CSVRowSerializer.header(of: sample))
        let line = CSVRowSerializer.row(
            fields: ["goal_id": "goal-9", "name": "House, Down Payment", "target_amount": "50000", "source_account_id": "acct-2"],
            header: header)
        #expect(line == "goal-9,\"House, Down Payment\",50000,acct-2")
        let plan = WritePlanBuilder.add(
            fields: ["goal_id": "goal-9", "name": "House, Down Payment", "target_amount": "50000", "source_account_id": "acct-2"],
            to: "Savings/goals.csv", fileText: sample)
        let out = try CSVRowSerializer.applyDiffs(plan.changes[0].rowDiffs, to: sample)
        #expect(out.components(separatedBy: "\n").last == line)
    }

    // T012 — the edit builder produces a modify diff that applyDiffs applies in place.
    @Test func editBuilderModifiesTargetRow() throws {
        let plan = WritePlanBuilder.edit(
            fields: ["goal_id": "goal-2", "name": "Vacation", "target_amount": "6500", "source_account_id": "acct-2"],
            rowRef: 2, before: "goal-2,Vacation,5000,acct-2", in: "Savings/goals.csv", fileText: sample)
        let out = try CSVRowSerializer.applyDiffs(plan.changes[0].rowDiffs, to: sample)
        #expect(out.contains("goal-2,Vacation,6500,acct-2"))
        #expect(!out.contains("goal-2,Vacation,5000,acct-2"))
    }
}
