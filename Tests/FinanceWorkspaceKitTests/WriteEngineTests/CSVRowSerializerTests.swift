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
}
