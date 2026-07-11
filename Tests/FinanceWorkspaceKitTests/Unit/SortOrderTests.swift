import Testing
import Foundation
@testable import FinanceWorkspaceKit

// Spec 010 UV-1, T011 — the canonical display order (composite key `(sortOrder ?? Int.max, id)`)
// applied once at the WorkspaceContext accessors, its degradation rules (SC-005), and engine
// order preservation (SC-004).

@Suite struct SortOrderTests {

    private static let groupsHeader = "account_group_id,name,group_type,sort_order"
    private static let accountsHeader =
        "account_id,display_name,institution,account_group,account_type,status,account_group_id,sort_order"

    private func accountRow(_ id: String, group: String, sortOrder: String = "") -> String {
        "\(id),\(id.uppercased()),Bank,checking,checking,active,\(group),\(sortOrder)"
    }

    @Test func explicitOrderFirstThenDefaultOrder() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        // g-c explicitly first, g-a second; g-b and g-d unordered → follow in ID order.
        fx.write("Accounts/account-groups.csv", Self.groupsHeader, [
            "g-a,Alpha,personal,20",
            "g-b,Beta,personal,",
            "g-c,Gamma,business,10",
            "g-d,Delta,custom,",
        ])
        let context = try fx.parse()
        #expect(context.accountGroups.map(\.accountGroupId) == ["g-c", "g-a", "g-b", "g-d"])
    }

    @Test func accountsOrderWithinGroupAndMixedValues() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        fx.write("Accounts/account-groups.csv", Self.groupsHeader, ["g-a,Alpha,personal,"])
        fx.write("Accounts/accounts.csv", Self.accountsHeader, [
            accountRow("acc-1", group: "g-a"),                 // unordered → after ordered ones
            accountRow("acc-2", group: "g-a", sortOrder: "20"),
            accountRow("acc-3", group: "g-a", sortOrder: "10"),
        ])
        let context = try fx.parse()
        #expect(context.accounts.map(\.accountId) == ["acc-3", "acc-2", "acc-1"])
    }

    @Test func duplicateValuesTieBreakByDefaultOrder() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        fx.write("Accounts/account-groups.csv", Self.groupsHeader, [
            "g-b,Beta,personal,10",
            "g-a,Alpha,personal,10",
        ])
        let context = try fx.parse()
        // Same sort_order → deterministic ID tie-break.
        #expect(context.accountGroups.map(\.accountGroupId) == ["g-a", "g-b"])
    }

    @Test func invalidValuesDegradeToAbsentWithAtMostAWarning() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        fx.write("Accounts/account-groups.csv", Self.groupsHeader, [
            "g-a,Alpha,personal,notanumber",
            "g-b,Beta,personal,-5",
            "g-c,Gamma,personal,10",
        ])
        let context = try fx.parse()
        let groups = context.accountGroups
        // Non-integer and negative read as absent; the file still loads all rows.
        #expect(groups.count == 3)
        #expect(groups.map(\.accountGroupId) == ["g-c", "g-a", "g-b"])
        #expect(groups.first { $0.accountGroupId == "g-a" }?.sortOrder == nil)
        #expect(groups.first { $0.accountGroupId == "g-b" }?.sortOrder == nil)
        // The non-integer cell warns (normalizer); it never blocks parsing.
        #expect(context.parseResults.flatMap(\.warnings).contains { $0.kind == .invalidInteger })
    }

    @Test func fileWithoutColumnKeepsDefaultOrder() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        fx.write("Accounts/account-groups.csv", "account_group_id,name,group_type", [
            "g-b,Beta,personal",
            "g-a,Alpha,personal",
        ])
        let context = try fx.parse()
        #expect(context.accountGroups.map(\.accountGroupId) == ["g-a", "g-b"])
        #expect(context.accountGroups.allSatisfy { $0.sortOrder == nil })
    }

    @Test func enginePreservesAccessorOrderIncludingOrphans() throws {
        let fx = FixtureWorkspace()
        defer { fx.cleanup() }
        fx.write("Accounts/account-groups.csv", Self.groupsHeader, [
            "g-a,Alpha,personal,20",
            "g-b,Beta,business,10",
        ])
        fx.write("Accounts/accounts.csv", Self.accountsHeader, [
            accountRow("acc-1", group: "g-a", sortOrder: "20"),
            accountRow("acc-2", group: "g-a", sortOrder: "10"),
            accountRow("acc-3", group: "g-b"),
            accountRow("acc-4", group: "zz-orphan"),   // group id not in account-groups.csv
            accountRow("acc-5", group: "aa-orphan"),   // orphans follow known groups, ID order
        ])
        let context = try fx.parse()
        let overview = AccountEngine().overview(context, asOf: Date(), settings: .defaults())
        // Group order: explicit (g-b before g-a), then orphans in ID order.
        #expect(overview.groups.map(\.accountGroupId) == ["g-b", "g-a", "aa-orphan", "zz-orphan"])
        // Account order within g-a follows the accessor (acc-2 stamped before acc-1).
        #expect(overview.groups.first { $0.accountGroupId == "g-a" }?.accountIds == ["acc-2", "acc-1"])
    }
}
