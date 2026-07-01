import Testing
import Foundation
@testable import FinanceWorkspaceKit

// US3 (T032) — TaxAdjustmentEngine: standard-vs-itemized flag, QBI, business x-ref, computed vs
// stored estimate, and idempotent standard-adjustment seed (SC-006/SC-011).

@Suite struct TaxAdjustmentEngineTests {

    private let settings = WorkspaceSettings(filingStatus: .single, taxYear: 2026, defaultCurrency: "USD", timezone: "UTC")

    private func makeWorkspace(withStandard: Bool = true, storedReturn: String? = nil) -> FixtureWorkspace {
        let fx = FixtureWorkspace()
        fx.write("Accounts/accounts.csv", FixtureWorkspace.acctHeader, [
            "acc-personal-bank,Checking,,checking,personal,active,grp-personal",
            "acc-business-bank,Business,,business,llc,active,grp-business"])
        fx.write("Accounts/account-groups.csv", FixtureWorkspace.groupHeader, [
            "grp-personal,Personal,personal", "grp-business,Business,business"])
        var adj = ["adj-item,schedule_a,8000.00,2026,estimated,",
                   "adj-atl,above_the_line,2000.00,2026,confirmed,",
                   "adj-sc,schedule_c,3000.00,2026,estimated,grp-business"]
        if withStandard { adj.insert("adj-standard,standard,15750.00,2026,estimated,", at: 0) }
        fx.write("Taxes/tax-adjustments.csv", FixtureWorkspace.taxAdjHeader, adj)
        if let storedReturn {
            fx.write("Taxes/estimates.csv", FixtureWorkspace.taxEstimateHeader, ["e1,2026,,,\(storedReturn)"])
        }
        fx.write("Accounts/transactions/2026-02.csv", FixtureWorkspace.txHeader, [
            FixtureWorkspace.tx("sal", "acc-personal-bank", "2026-02-10", "60000", type: "standard", category: "cat-salary"),
            FixtureWorkspace.tx("bin", "acc-business-bank", "2026-02-10", "10000", type: "standard", category: "cat-business-income"),
            FixtureWorkspace.tx("bex", "acc-business-bank", "2026-02-15", "-3000", type: "standard", category: "cat-housing")])
        return fx
    }

    @Test func deductionSummaryFlagsGreaterAndComputesQBI() throws {
        let fx = makeWorkspace(); defer { fx.cleanup() }
        let s = TaxAdjustmentEngine().deductionSummary(try fx.parse(), settings: settings)
        #expect(s.standardTotal == Decimal(15750))
        #expect(s.itemizedTotal == Decimal(8000))
        #expect(s.recommended == .standard)                 // greater, not auto-committed
        #expect(s.qbiDeduction == Decimal(1400))            // 0.20 × (10000 − 3000) business net
        #expect(s.scheduleC == Decimal(3000))
        // gross 70000 − 2000 atl − 3000 scheduleC − 1400 qbi − 15750 std = 47850
        #expect(s.taxableIncomeAfterAdjustments == Decimal(47850))
        // Schedule C reconciles to the ledger (3000 claimed vs 3000 expenses).
        #expect(s.businessExpenseByGroup.first { $0.accountGroupId == "grp-business" }?.divergence == 0)
    }

    @Test func estimateComputedThenStoredOverride() throws {
        let computed = TaxAdjustmentEngine().taxEstimate(try makeWorkspace().parse(), settings: settings)
        #expect(computed.source == .computed)
        #expect(computed.projectedLiability > 0)             // brackets applied to 47850

        let fx = makeWorkspace(storedReturn: "1234.00"); defer { fx.cleanup() }
        let stored = TaxAdjustmentEngine().taxEstimate(try fx.parse(), settings: settings)
        #expect(stored.source == .stored)
        #expect(stored.estimatedReturn == Decimal(string: "1234.00"))
    }

    @Test func seedStandardIsIdempotent() throws {
        let fx = makeWorkspace(withStandard: false); defer { fx.cleanup() }
        let engine = TaxAdjustmentEngine()
        #expect(try engine.seedStandardAdjustmentIfMissing(workspaceURL: fx.root, settings: settings) == true)
        #expect(try engine.seedStandardAdjustmentIfMissing(workspaceURL: fx.root, settings: settings) == false)
        let adjustments = try fx.parse().taxAdjustments.filter { $0.adjustmentType == .standard && $0.taxYear == 2026 }
        #expect(adjustments.count == 1)                      // exactly one, not duplicated
    }
}
