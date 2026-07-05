import Foundation
import Testing
@testable import FinanceWorkspaceApp
import FinanceWorkspaceKit

// T009 — ProjectionStore: one consistent snapshot, typed states passed through, and the
// read-only guarantee (SC-005): a full build leaves the workspace byte-identical.

@Suite struct ProjectionStoreTests {

    @Test func buildsOneConsistentSnapshot() throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let asOf = ISO8601DateFormatter.day.date(from: "2026-06-30")!

        let snapshot = try ProjectionStore.buildSync(workspaceURL: fixture.root, asOf: asOf)

        #expect(snapshot.dashboard.cards.count == 5)
        #expect(snapshot.settings.taxYear == 2026)
        #expect(snapshot.accounts.accounts.count == 3)
        #expect(snapshot.goals.count == 1)
        // Same as-of everywhere: the tax projection uses the settings year.
        #expect(snapshot.tax.taxYear == 2026)
    }

    @Test func typedStatesPassThrough() throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let asOf = ISO8601DateFormatter.day.date(from: "2026-06-30")!

        let snapshot = try ProjectionStore.buildSync(workspaceURL: fixture.root, asOf: asOf)

        // No portfolio expected-return rate in the fixture → the investments card reports
        // the typed "rate not set" state, never a derived value (FR-031).
        let investments = snapshot.dashboard.cards.first { $0.kind == "investments" }
        #expect(investments?.estimatedRate == .rateNotSet)
    }

    @Test func fullBuildIsReadOnly() throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        let before = fixture.contentSnapshot()

        _ = try ProjectionStore.buildSync(
            workspaceURL: fixture.root,
            asOf: ISO8601DateFormatter.day.date(from: "2026-06-30")!)

        let after = fixture.contentSnapshot()
        #expect(before == after)                       // byte-identical (SC-005)
        #expect(before.isEmpty == false)
    }

    @Test func closedYearsScansArchiveNames() throws {
        let fixture = AppFixture.standard()
        defer { fixture.cleanup() }
        fixture.write("Taxes/archive/2024-tax-adjustments.csv", "tax_adjustment_id", [])
        fixture.write("Taxes/archive/2024-estimated-payments.csv", "payment_id", [])
        fixture.write("Taxes/archive/2023-tax-adjustments.csv", "tax_adjustment_id", [])

        #expect(ProjectionStore.closedYears(workspaceURL: fixture.root) == [2024, 2023])
    }
}

extension ISO8601DateFormatter {
    static let day: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt
    }()
}
