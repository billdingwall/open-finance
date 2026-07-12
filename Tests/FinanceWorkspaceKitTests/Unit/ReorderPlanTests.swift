import Testing
import Foundation
@testable import FinanceWorkspaceKit

// Spec 010 UV-1, T012 — ReorderPlanBuilder: gap-of-10 stamping (FR-006), only-`sort_order`-cell
// diffs, scope limits, header extension on first reorder, and the WriteService round-trip
// (backup + atomic apply + drift refusal — SC-003).

@Suite struct ReorderPlanTests {

    private static let groupsHeaderBare = "account_group_id,name,group_type"
    private static let groupsHeaderStamped = "account_group_id,name,group_type,sort_order"

    private func groupsFileText(header: String, rows: [String]) -> String {
        (["# schema_version: 1", header] + rows).joined(separator: "\n") + "\n"
    }

    @Test func firstReorderExtendsHeaderAndStampsWholeScope() throws {
        let text = groupsFileText(header: Self.groupsHeaderBare, rows: [
            "g-a,Alpha,personal",
            "g-b,Beta,personal",
            "g-c,Gamma,business",
        ])
        let plan = try ReorderPlanBuilder.plan(orderedIds: ["g-c", "g-a", "g-b"],
                                               keyColumn: "account_group_id",
                                               in: "Accounts/account-groups.csv", fileText: text)
        let change = try #require(plan.changes.first)
        #expect(plan.intent == .edit)
        #expect(change.headerChange == HeaderChange(before: Self.groupsHeaderBare,
                                                    after: Self.groupsHeaderStamped))
        // Every row in scope is stamped gap-of-10 in the new order.
        let updated = try CSVRowSerializer.applyDiffs(
            change.rowDiffs,
            to: CSVRowSerializer.replaceHeader(change.headerChange!, in: text))
        #expect(updated == groupsFileText(header: Self.groupsHeaderStamped, rows: [
            "g-a,Alpha,personal,20",
            "g-b,Beta,personal,30",
            "g-c,Gamma,business,10",
        ]))
    }

    @Test func reorderOnStampedFileCompactsWithoutHeaderChange() throws {
        let text = groupsFileText(header: Self.groupsHeaderStamped, rows: [
            "g-a,Alpha,personal,10",
            "g-b,Beta,personal,25",     // hand-edited value gets compacted
            "g-c,Gamma,business,30",
        ])
        let plan = try ReorderPlanBuilder.plan(orderedIds: ["g-b", "g-c", "g-a"],
                                               keyColumn: "account_group_id",
                                               in: "Accounts/account-groups.csv", fileText: text)
        let change = try #require(plan.changes.first)
        #expect(change.headerChange == nil)
        let updated = try CSVRowSerializer.applyDiffs(change.rowDiffs, to: text)
        #expect(updated == groupsFileText(header: Self.groupsHeaderStamped, rows: [
            "g-a,Alpha,personal,30",
            "g-b,Beta,personal,10",
            "g-c,Gamma,business,20",
        ]))
    }

    @Test func unchangedRowsProduceNoDiffs() throws {
        let text = groupsFileText(header: Self.groupsHeaderStamped, rows: [
            "g-a,Alpha,personal,10",
            "g-b,Beta,personal,20",
        ])
        let plan = try ReorderPlanBuilder.plan(orderedIds: ["g-a", "g-b"],
                                               keyColumn: "account_group_id",
                                               in: "Accounts/account-groups.csv", fileText: text)
        #expect(plan.changes.first?.rowDiffs.isEmpty == true)
    }

    @Test func accountScopeIsLimitedToOneGroup() throws {
        let header = "account_id,display_name,institution,account_group,account_type,status,account_group_id,sort_order"
        let text = (["# schema_version: 1", header,
                     "acc-1,A1,Bank,checking,checking,active,g-a,",
                     "acc-2,A2,Bank,checking,checking,active,g-a,",
                     "acc-3,A3,Bank,savings,hysa,active,g-b,",
                    ]).joined(separator: "\n") + "\n"
        // Reorder only g-a's accounts; g-b's row must be untouched.
        let plan = try ReorderPlanBuilder.plan(orderedIds: ["acc-2", "acc-1"],
                                               keyColumn: "account_id",
                                               in: "Accounts/accounts.csv", fileText: text)
        let change = try #require(plan.changes.first)
        #expect(change.headerChange == nil)
        #expect(change.rowDiffs.count == 2)                       // acc-1 + acc-2 only
        #expect(!change.rowDiffs.contains { $0.rowRef == 3 })     // acc-3 untouched
        let updated = try CSVRowSerializer.applyDiffs(change.rowDiffs, to: text)
        #expect(updated.contains("acc-1,A1,Bank,checking,checking,active,g-a,20"))
        #expect(updated.contains("acc-2,A2,Bank,checking,checking,active,g-a,10"))
        #expect(updated.contains("acc-3,A3,Bank,savings,hysa,active,g-b,\n"))
    }

    @Test func headerExtensionPadsOutOfScopeRows() throws {
        let header = "account_id,display_name,institution,account_group,account_type,status,account_group_id"
        let text = (["# schema_version: 1", header,
                     "acc-1,A1,Bank,checking,checking,active,g-a",
                     "acc-2,A2,Bank,savings,hysa,active,g-b",
                    ]).joined(separator: "\n") + "\n"
        let plan = try ReorderPlanBuilder.plan(orderedIds: ["acc-1"],
                                               keyColumn: "account_id",
                                               in: "Accounts/accounts.csv", fileText: text)
        let change = try #require(plan.changes.first)
        #expect(change.headerChange != nil)
        let updated = try CSVRowSerializer.applyDiffs(
            change.rowDiffs,
            to: CSVRowSerializer.replaceHeader(change.headerChange!, in: text))
        // Out-of-scope row is padded to the new column count, value stays empty.
        #expect(updated.contains("acc-2,A2,Bank,savings,hysa,active,g-b,\n"))
        #expect(updated.contains("acc-1,A1,Bank,checking,checking,active,g-a,10"))
    }

    @Test func writeServiceRoundTripPersistsOrderAndBacksUp() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        fx.write("Accounts/account-groups.csv", Self.groupsHeaderBare, [
            "g-a,Alpha,personal",
            "g-b,Beta,personal",
        ])
        let fileURL = fx.root.appendingPathComponent("Accounts/account-groups.csv")
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let plan = try ReorderPlanBuilder.plan(orderedIds: ["g-b", "g-a"],
                                               keyColumn: "account_group_id",
                                               in: "Accounts/account-groups.csv", fileText: text)
        let service = WriteService(workspaceURL: fx.root)
        let result = try service.apply(service.preview(plan),
                                       workspaceState: .available, fileStates: [:])
        #expect(result.backups.count == 1)
        // Reparse: the canonical accessor order reflects the write.
        let context = try fx.parse()
        #expect(context.accountGroups.map(\.accountGroupId) == ["g-b", "g-a"])
        #expect(context.accountGroups.map(\.sortOrder) == [10, 20])
    }

    @Test func driftAfterPreviewRefusesAndLeavesFileUntouched() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        fx.write("Accounts/account-groups.csv", Self.groupsHeaderBare, [
            "g-a,Alpha,personal",
            "g-b,Beta,personal",
        ])
        let fileURL = fx.root.appendingPathComponent("Accounts/account-groups.csv")
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let plan = try ReorderPlanBuilder.plan(orderedIds: ["g-b", "g-a"],
                                               keyColumn: "account_group_id",
                                               in: "Accounts/account-groups.csv", fileText: text)
        let service = WriteService(workspaceURL: fx.root)
        let stamped = service.preview(plan)
        // The file changes between preview and apply (e.g. sync delivered an edit).
        let tampered = text + "g-z,Zeta,custom\n"
        try Data(tampered.utf8).write(to: fileURL)
        #expect(throws: WriteError.driftDetected(path: "Accounts/account-groups.csv")) {
            try service.apply(stamped, workspaceState: .available, fileStates: [:])
        }
        // Pre-write state preserved (atomicity — SC-003).
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == tampered)
    }
}
