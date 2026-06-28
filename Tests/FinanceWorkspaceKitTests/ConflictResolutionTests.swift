import Testing
import Foundation
@testable import FinanceWorkspaceKit

@Suite struct ConflictResolutionTests {

    // T036 / SC-006 — every choice yields a deterministic plan and no choice loses all data.
    @Test func eachChoicePreservesDataAndIsDeterministic() {
        let mine = ConflictResolver.plan(for: .keepMine)
        #expect(mine.keepCurrent && !mine.promoteOther && !mine.preserveOtherAsCopy)
        #expect(mine.preservesData)

        let cloud = ConflictResolver.plan(for: .keepiCloud)
        #expect(!cloud.keepCurrent && cloud.promoteOther && !cloud.preserveOtherAsCopy)
        #expect(cloud.preservesData)

        // keep both retains the current AND preserves the other as a copy — neither version is lost.
        let both = ConflictResolver.plan(for: .keepBoth)
        #expect(both.keepCurrent && both.preserveOtherAsCopy)
        #expect(both.preservesData)

        // No silent auto-merge: the three choices are distinct plans.
        #expect(Set([mine, cloud, both]).count == 3)
        // All choices mark the conflict resolved.
        #expect(ConflictChoice.allCases.allSatisfy { ConflictResolver.plan(for: $0).markResolved })
    }

    @Test func conflictedCopyNamingIsStable() {
        let url = URL(fileURLWithPath: "/ws/Finance/Accounts/accounts.csv")
        #expect(ConflictResolver.conflictedCopyURL(for: url, index: 0).lastPathComponent
                == "accounts (conflicted copy 1).csv")
        #expect(ConflictResolver.conflictedCopyURL(for: url, index: 1).lastPathComponent
                == "accounts (conflicted copy 2).csv")

        let noExt = URL(fileURLWithPath: "/ws/Finance/Workspace")
        #expect(ConflictResolver.conflictedCopyURL(for: noExt, index: 0).lastPathComponent
                == "Workspace (conflicted copy 1)")
    }
}
